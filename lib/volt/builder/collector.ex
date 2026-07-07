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

    state = %Volt.Builder.Collector.State{
      ctx: ctx,
      root: Path.dirname(entry_path),
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
    path = module_path(abs_path)

    cond do
      MapSet.member?(state.seen, abs_path) ->
        {:ok, state}

      Volt.Assets.asset?(path) ->
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

  defp module_path(module_id), do: module_id |> Volt.URL.split_query() |> elem(0)

  defp asset_module_query?(module_id) do
    {_path, query} = Volt.URL.split_query(module_id)

    query
    |> Volt.URL.decode_query()
    |> Map.keys()
    |> Enum.any?(&(&1 in ["raw", "url", "inline", "no-inline"]))
  end

  defp collect_asset(abs_path, label, state) do
    source = ""

    {:ok,
     %{
       state
       | seen: MapSet.put(state.seen, abs_path),
         files: [{abs_path, label, source} | state.files],
         dep_map: Map.put(state.dep_map, abs_path, %Volt.Builder.Dependencies{})
     }}
  end

  defp read_module(module_id, plugins) do
    with nil <- read_embedded_module(module_id, plugins),
         nil <- read_plugin_module(module_id, plugins) do
      path = module_path(module_id)

      case File.read(path) do
        {:ok, source} -> {:ok, source, nil}
        error -> error
      end
    end
  end

  defp read_embedded_module(module_id, plugins) do
    case Volt.PluginRunner.embedded_module(plugins, module_id) do
      {:ok, module, _parent} ->
        {:ok, module.source, Volt.Plugin.EmbeddedModule.content_type(module)}

      {:error, _} = error ->
        error

      nil ->
        nil
    end
  end

  defp read_plugin_module(module_id, plugins) do
    case Volt.PluginRunner.load(plugins, module_id) do
      {:ok, code, content_type} -> {:ok, code, content_type}
      {:ok, code} -> {:ok, code, nil}
      nil -> nil
    end
  end

  defp process_source(abs_path, label, source, content_type, state) do
    graph_source = graph_source(abs_path, source, content_type, state.ctx)

    state = %{
      state
      | seen: MapSet.put(state.seen, abs_path),
        files: [{abs_path, label, source} | state.files]
    }

    case extract_typed_imports(
           graph_source,
           abs_path,
           content_type,
           state.ctx.loaders,
           state.ctx.plugins,
           graph_source != source
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

      {:error, _} = error ->
        error
    end
  end

  defp resolve_dep_map_specifier(dep_map, importer, specifier, resolved_path) do
    case dep_map[importer] do
      nil ->
        dep_map

      deps ->
        deps = %{
          deps
          | static: replace_specifier(deps.static, specifier, resolved_path),
            dynamic: replace_specifier(deps.dynamic, specifier, resolved_path)
        }

        Map.put(dep_map, importer, deps)
    end
  end

  defp replace_specifier(specs, specifier, resolved_path) do
    Enum.map(specs, fn
      ^specifier -> resolved_path
      other -> other
    end)
  end

  defp graph_source(path, source, _content_type, ctx) do
    if asset_module_query?(path) do
      source
    else
      case Volt.Builder.Compiler.compile(path, source, ctx) do
        {:ok, %{type: :js, code: code}} -> code
        _ -> source
      end
    end
  end

  defp extract_typed_imports(source, path, content_type, loaders, plugins, compiled?) do
    base_path = module_path(path)
    ext = Path.extname(base_path)
    filename = Volt.JS.Extensions.apply_loader(Path.basename(base_path), loaders)

    case if(compiled?,
           do: nil,
           else: Volt.PluginRunner.extract_imports(plugins, path, source, loaders: loaders)
         ) do
      nil ->
        cond do
          asset_module_query?(path) ->
            {:ok, %Volt.JS.ImportExtractor.Result{imports: [], workers: []}}

          Volt.MIME.javascript?(content_type) ->
            extract_js_typed_imports(source, filename)

          Volt.MIME.css?(content_type) ->
            {:ok, %Volt.JS.ImportExtractor.Result{imports: [], workers: []}}

          ext == ".json" or ext in Volt.JS.Extensions.css() ->
            {:ok, %Volt.JS.ImportExtractor.Result{imports: [], workers: []}}

          true ->
            extract_js_typed_imports(source, filename)
        end

      result ->
        result
    end
  end

  defp extract_js_typed_imports(source, filename) do
    Volt.JS.ImportExtractor.extract_typed(source, filename, include_require: true)
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
    {path, query} = Volt.URL.split_query(resolved_path)
    [relative_path | rest] = path |> String.split("/node_modules/") |> Enum.reverse()

    label =
      if rest != [] do
        relative_path
      else
        relative = Path.relative_to(path, root)

        if Path.type(relative) == :absolute do
          "_external/" <>
            Path.basename(Path.dirname(path)) <> "/" <> Path.basename(path)
        else
          relative
        end
      end
      |> with_query_suffix(query)

    cond do
      Path.extname(label) == ".json" -> Path.rootname(label) <> ".json.js"
      Path.extname(label) in Volt.JS.Extensions.css() -> label <> ".js"
      query != "" -> label <> ".js"
      true -> label
    end
  end

  defp with_query_suffix(label, ""), do: label

  defp with_query_suffix(label, query) do
    suffix =
      query
      |> URI.decode_query()
      |> Map.keys()
      |> Enum.sort()
      |> Enum.join("-")

    label <> "." <> suffix
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

    %Volt.Builder.Dependencies{static: Enum.reverse(statics), dynamic: Enum.reverse(dynamics)}
  end
end
