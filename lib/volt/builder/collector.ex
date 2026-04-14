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
    state = %{ctx: ctx, files: [], seen: MapSet.new(), dep_map: %{}, workers: %{}}

    case do_collect(entry_path, label, state) do
      {:ok, state} -> {:ok, Enum.reverse(state.files), state.dep_map, state.workers}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, label, state) do
    if MapSet.member?(state.seen, abs_path) do
      {:ok, state}
    else
      case File.read(abs_path) do
        {:ok, source} -> process_source(abs_path, label, source, state)
        {:error, reason} -> {:error, {:file_read_error, abs_path, reason}}
      end
    end
  end

  defp process_source(abs_path, label, source, state) do
    state = %{
      state
      | seen: MapSet.put(state.seen, abs_path),
        files: [{abs_path, label, source} | state.files]
    }

    case extract_typed_imports(source, abs_path) do
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
        label =
          if NPM.PackageResolver.relative?(original_specifier),
            do: Path.basename(resolved_path),
            else: original_specifier

        state = %{
          state
          | dep_map:
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

  defp extract_typed_imports(source, path) do
    ext = Path.extname(path)
    filename = Path.basename(path)

    if ext == ".vue" do
      case Volt.VueImports.extract(source) do
        {:ok, specs} -> {:ok, %{imports: Enum.map(specs, &{:static, &1}), workers: []}}
        error -> error
      end
    else
      extract_js_typed_imports(source, filename)
    end
  end

  defp extract_js_typed_imports(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        {_ast, acc} =
          OXC.postwalk(ast, %{imports: [], workers: []}, fn
            %{type: "ImportDeclaration", source: %{value: spec}} = node, acc ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: "ExportNamedDeclaration", source: %{value: spec}} = node, acc
            when is_binary(spec) ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: "ExportAllDeclaration", source: %{value: spec}} = node, acc ->
              {node, update_in(acc.imports, &[{:static, spec} | &1])}

            %{type: "ImportExpression", source: %{type: "Literal", value: spec}} = node, acc
            when is_binary(spec) ->
              {node, update_in(acc.imports, &[{:dynamic, spec} | &1])}

            %{
              type: "NewExpression",
              callee: %{type: "Identifier", name: worker_type},
              arguments: [first_arg | _]
            } = node,
            acc
            when worker_type in ["Worker", "SharedWorker"] ->
              case Volt.WorkerRewriter.extract_specifier(first_arg) do
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

  defp split_imports(typed_imports) do
    {statics, dynamics} =
      Enum.reduce(typed_imports, {[], []}, fn
        {:static, spec}, {s, d} -> {[spec | s], d}
        {:dynamic, spec}, {s, d} -> {s, [spec | d]}
      end)

    %{static: Enum.reverse(statics), dynamic: Enum.reverse(dynamics)}
  end
end
