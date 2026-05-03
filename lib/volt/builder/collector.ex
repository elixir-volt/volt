defmodule Volt.Builder.Collector do
  @moduledoc "Walks the dependency graph from entry files, collecting modules and workers."

  alias Volt.Builder.Resolver

  @doc """
  Walk the dependency graph from an entry file.

  Returns `{:ok, modules, dep_map, workers}` where:
  - `modules` is `[{abs_path, label, source}]` in dependency order
  - `dep_map` is `%{abs_path => %{static: [abs_path], dynamic: [abs_path]}}`
  - `workers` is `%{importer_path => %{specifier => worker_abs_path}}`
  """
  def collect(entry_path, ctx) do
    label = Path.basename(entry_path)

    state = %{
      ctx: ctx,
      root: Path.dirname(entry_path),
      files: [],
      seen: MapSet.new(),
      dep_map: %{},
      workers: %{},
      specifier_labels: %{},
      used_labels: MapSet.new([label]),
      path_labels: %{entry_path => label}
    }

    case do_collect(entry_path, label, state) do
      {:ok, state} ->
        {:ok, Enum.reverse(state.files), state.dep_map, state.workers, state.specifier_labels,
         state.path_labels}

      {:error, _} = error ->
        error
    end
  end

  defp do_collect(abs_path, label, state) do
    cond do
      MapSet.member?(state.seen, abs_path) or
          (Path.extname(abs_path) in Volt.JS.Extensions.css() and
             not Volt.CSS.Modules.css_module?(abs_path)) ->
        {:ok, state}

      Volt.Assets.asset?(abs_path) ->
        collect_asset(abs_path, label, state)

      true ->
        case read_module(abs_path, state.ctx.plugins) do
          {:ok, source, content_type} ->
            process_source(abs_path, label, source, content_type, state)

          {:error, reason} ->
            {:error, {:file_read_error, abs_path, reason}}
        end
    end
  end

  defp collect_asset(abs_path, label, state) do
    source = ""

    {:ok,
     %{
       state
       | seen: MapSet.put(state.seen, abs_path),
         files: [{abs_path, label, source} | state.files],
         dep_map: Map.put(state.dep_map, abs_path, %{static: [], dynamic: []})
     }}
  end

  defp read_module(path, plugins) do
    case Volt.PluginRunner.load(plugins, path) do
      {:ok, code, content_type} ->
        {:ok, code, content_type}

      {:ok, code} ->
        {:ok, code, nil}

      nil ->
        case File.read(path) do
          {:ok, source} -> {:ok, source, nil}
          error -> error
        end
    end
  end

  defp process_source(abs_path, label, source, content_type, state) do
    source = Volt.JS.GlobImport.transform(source, Path.dirname(abs_path), Path.basename(abs_path))

    state = %{
      state
      | seen: MapSet.put(state.seen, abs_path),
        files: [{abs_path, label, source} | state.files]
    }

    case extract_typed_imports(
           source,
           abs_path,
           content_type,
           state.ctx.loaders,
           state.ctx.plugins
         ) do
      {:ok, %{imports: typed_imports, workers: worker_specs}} ->
        state = %{
          state
          | dep_map: Map.put(state.dep_map, abs_path, split_imports(typed_imports))
        }

        {state, worker_specs} = resolve_workers(worker_specs, abs_path, state)
        specifiers = Enum.map(typed_imports, fn {_type, spec} -> spec end)

        worker_imports =
          Enum.map(worker_specs, fn {specifier, resolved_path} ->
            {:resolved, specifier, resolved_path}
          end)

        collect_imports(specifiers ++ worker_imports, abs_path, state)

      {:error, _} = error ->
        error
    end
  end

  defp collect_imports([], _importer, state) do
    {:ok, state}
  end

  defp collect_imports([specifier | rest], importer, state) do
    case resolve_specifier(specifier, importer, state.ctx) do
      :skip ->
        collect_imports(rest, importer, state)

      {:ok, resolved_path, original_specifier} ->
        if Path.extname(resolved_path) in Volt.JS.Extensions.css() and
             not Volt.CSS.Modules.css_module?(resolved_path) do
          collect_imports(rest, importer, state)
        else
          {label, state} =
            if MapSet.member?(state.seen, resolved_path) do
              {state.path_labels[resolved_path], state}
            else
              unique_label(original_specifier, resolved_path, state)
            end

          importer_labels = Map.get(state.specifier_labels, importer, %{})

          state = %{
            state
            | specifier_labels:
                Map.put(
                  state.specifier_labels,
                  importer,
                  Map.put_new(importer_labels, original_specifier, label)
                ),
              dep_map:
                resolve_dep_map_specifier(
                  state.dep_map,
                  importer,
                  original_specifier,
                  resolved_path
                )
          }

          case do_collect(resolved_path, label, state) do
            {:ok, state} ->
              collect_imports(rest, importer, state)

            {:error, _} = error ->
              error
          end
        end

      {:error, _} = error ->
        error
    end
  end

  defp resolve_dep_map_specifier(dep_map, importer, specifier, resolved_path) do
    case dep_map[importer] do
      nil ->
        dep_map

      deps ->
        deps =
          Map.new(deps, fn {type, specs} ->
            {type,
             Enum.map(specs, fn
               ^specifier -> resolved_path
               other -> other
             end)}
          end)

        Map.put(dep_map, importer, deps)
    end
  end

  defp extract_typed_imports(source, path, content_type, loaders, plugins) do
    ext = Path.extname(path)
    filename = Volt.JS.Extensions.apply_loader(Path.basename(path), loaders)

    case Volt.PluginRunner.extract_imports(plugins, path, source, loaders: loaders) do
      nil ->
        cond do
          content_type in ~w(application/javascript text/javascript) ->
            extract_js_typed_imports(source, filename)

          ext == ".json" or Volt.CSS.Modules.css_module?(path) ->
            {:ok, %{imports: [], workers: []}}

          true ->
            extract_js_typed_imports(source, filename)
        end

      result ->
        result
    end
  end

  defp extract_js_typed_imports(source, filename) do
    needs_postwalk =
      String.contains?(source, "require(") or String.contains?(source, "new Worker") or
        String.contains?(source, "new SharedWorker")

    if needs_postwalk do
      extract_js_typed_imports_slow(source, filename)
    else
      case OXC.collect_imports(source, filename) do
        {:ok, imports} ->
          typed =
            Enum.map(imports, fn %{specifier: spec, type: type} ->
              {type, spec}
            end)

          {:ok, %{imports: typed, workers: []}}

        {:error, _} = error ->
          error
      end
    end
  end

  defp extract_js_typed_imports_slow(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        {_ast, acc} =
          OXC.postwalk(ast, %{imports: [], workers: []}, fn
            %{type: :import_declaration, source: %{value: spec}} = node, acc ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: :export_named_declaration, source: %{value: spec}} = node, acc
            when is_binary(spec) ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: :export_all_declaration, source: %{value: spec}} = node, acc ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: :import_expression, source: %{type: :literal, value: spec}} = node, acc
            when is_binary(spec) ->
              {node, update_in(acc.imports, &[{:dynamic, spec} | &1])}

            %{
              type: :call_expression,
              callee: %{type: :identifier, name: "require"},
              arguments: [%{type: :literal, value: spec} | _]
            } = node,
            acc
            when is_binary(spec) ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{
              type: :new_expression,
              callee: %{type: :identifier, name: worker_type},
              arguments: [first_arg | _]
            } = node,
            acc
            when worker_type in ["Worker", "SharedWorker"] ->
              case Volt.JS.WorkerRewriter.extract_specifier(first_arg) do
                {:ok, spec, _s, _e} -> {node, update_in(acc.workers, &[spec | &1])}
                nil -> {node, acc}
              end

            node, acc ->
              {node, acc}
          end)

        {:ok, %{imports: Enum.reverse(acc.imports), workers: Enum.reverse(acc.workers)}}

      {:error, _} ->
        case OXC.imports(source, filename) do
          {:ok, specs} -> {:ok, %{imports: Enum.map(specs, &{:static, &1}), workers: []}}
          error -> error
        end
    end
  end

  defp resolve_workers(worker_specs, importer, state) do
    Enum.reduce(worker_specs, {state, []}, fn specifier, {acc_state, resolved_specs} ->
      case Resolver.resolve(specifier, importer, acc_state.ctx) do
        {:ok, resolved_path} ->
          importer_map = Map.get(acc_state.workers, importer, %{})

          acc_state = %{
            acc_state
            | workers:
                Map.put(
                  acc_state.workers,
                  importer,
                  Map.put(importer_map, specifier, resolved_path)
                )
          }

          {acc_state, [{specifier, resolved_path} | resolved_specs]}

        _ ->
          {acc_state, resolved_specs}
      end
    end)
    |> then(fn {resolved_state, resolved_specs} ->
      {resolved_state, Enum.reverse(resolved_specs)}
    end)
  end

  defp resolve_specifier(specifier, importer, ctx) when is_binary(specifier) do
    case Resolver.resolve(specifier, importer, ctx) do
      :skip -> :skip
      {:ok, resolved_path} -> {:ok, resolved_path, specifier}
      {:error, _} = error -> error
    end
  end

  defp resolve_specifier({:resolved, specifier, resolved_path}, _importer, _ctx) do
    {:ok, resolved_path, specifier}
  end

  defp unique_label(_specifier, resolved_path, state) do
    base_label = module_label(resolved_path, state.root)
    label = deduplicate_label(base_label, resolved_path, state.used_labels)

    state = %{
      state
      | used_labels: MapSet.put(state.used_labels, label),
        path_labels: Map.put(state.path_labels, resolved_path, label)
    }

    {label, state}
  end

  defp module_label(resolved_path, root) do
    parts = String.split(resolved_path, "/node_modules/")

    label =
      if length(parts) > 1 do
        List.last(parts)
      else
        relative = Path.relative_to(resolved_path, root)

        if Path.type(relative) == :absolute do
          "_external/" <>
            Path.basename(Path.dirname(resolved_path)) <> "/" <> Path.basename(resolved_path)
        else
          relative
        end
      end

    cond do
      Path.extname(label) == ".json" -> Path.rootname(label) <> ".json.js"
      Volt.CSS.Modules.css_module?(label) -> label <> ".js"
      true -> label
    end
  end

  defp deduplicate_label(label, resolved_path, used) do
    if MapSet.member?(used, label) do
      parent = resolved_path |> Path.dirname() |> Path.basename()
      candidate = parent <> "/" <> label

      if MapSet.member?(used, candidate) do
        deduplicate_label(candidate <> "_2", resolved_path, used)
      else
        candidate
      end
    else
      label
    end
  end

  defp split_imports(typed_imports) do
    {statics, dynamics} =
      Enum.reduce(typed_imports, {[], []}, fn
        {:static, spec}, {s, d} -> {[spec | s], d}
        {:dynamic, spec}, {s, d} -> {s, [spec | d]}
      end)

    %{static: Enum.reverse(statics), dynamic: Enum.reverse(dynamics)}
  end
end
