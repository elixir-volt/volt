defmodule Volt.Builder.Collector do
  @moduledoc false

  alias Volt.Builder.Resolver

  @doc """
  Walk the dependency graph from an entry file.

  Returns `{:ok, modules, dep_map}` where:
  - `modules` is `[{abs_path, label, source}]` in dependency order
  - `dep_map` is `%{abs_path => %{static: [abs_path], dynamic: [abs_path]}}`
  """
  def collect(entry_path, ctx) do
    label = Path.basename(entry_path)

    case do_collect(entry_path, label, ctx, [], MapSet.new(), %{}) do
      {:ok, files, _seen, dep_map} -> {:ok, Enum.reverse(files), dep_map}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, label, ctx, files, seen, dep_map) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen, dep_map}
    else
      case File.read(abs_path) do
        {:ok, source} ->
          seen = MapSet.put(seen, abs_path)
          files = [{abs_path, label, source} | files]

          case extract_typed_imports(source, abs_path) do
            {:ok, typed_imports} ->
              dep_map = Map.put(dep_map, abs_path, split_imports(typed_imports))
              specifiers = Enum.map(typed_imports, fn {_type, spec} -> spec end)
              collect_imports(specifiers, abs_path, ctx, files, seen, dep_map)

            {:error, _} = error ->
              error
          end

        {:error, reason} ->
          {:error, {:file_read_error, abs_path, reason}}
      end
    end
  end

  defp collect_imports([], _importer, _ctx, files, seen, dep_map) do
    {:ok, files, seen, dep_map}
  end

  defp collect_imports([specifier | rest], importer, ctx, files, seen, dep_map) do
    case Resolver.resolve(specifier, importer, ctx) do
      :skip ->
        collect_imports(rest, importer, ctx, files, seen, dep_map)

      {:ok, resolved_path} ->
        label = if Resolver.relative?(specifier), do: Path.basename(resolved_path), else: specifier

        dep_map = resolve_dep_map_specifier(dep_map, importer, specifier, resolved_path)

        case do_collect(resolved_path, label, ctx, files, seen, dep_map) do
          {:ok, files, seen, dep_map} ->
            collect_imports(rest, importer, ctx, files, seen, dep_map)

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
            {type, Enum.map(specs, fn
              ^specifier -> resolved_path
              other -> other
            end)}
          end)

        Map.put(dep_map, importer, deps)
    end
  end

  # ── Import extraction ───────────────────────────────────────────────

  defp extract_typed_imports(source, path) do
    ext = Path.extname(path)
    filename = Path.basename(path)

    if ext == ".vue" do
      case extract_vue_imports(source) do
        {:ok, specs} -> {:ok, Enum.map(specs, &{:static, &1})}
        error -> error
      end
    else
      extract_js_typed_imports(source, filename)
    end
  end

  defp extract_js_typed_imports(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        {_ast, imports} =
          OXC.postwalk(ast, [], fn
            %{type: "ImportDeclaration", source: %{value: spec}} = node, acc ->
              {node, [{:static, spec} | acc]}

            %{type: "ExportNamedDeclaration", source: %{value: spec}} = node, acc
            when is_binary(spec) ->
              {node, [{:static, spec} | acc]}

            %{type: "ExportAllDeclaration", source: %{value: spec}} = node, acc ->
              {node, [{:static, spec} | acc]}

            %{type: "ImportExpression", source: %{type: "Literal", value: spec}} = node, acc
            when is_binary(spec) ->
              {node, [{:dynamic, spec} | acc]}

            node, acc ->
              {node, acc}
          end)

        {:ok, Enum.reverse(imports)}

      {:error, _} ->
        case OXC.imports(source, filename) do
          {:ok, specs} -> {:ok, Enum.map(specs, &{:static, &1})}
          error -> error
        end
    end
  end

  defp extract_vue_imports(source), do: Volt.VueImports.extract(source)

  defp split_imports(typed_imports) do
    {statics, dynamics} =
      Enum.reduce(typed_imports, {[], []}, fn
        {:static, spec}, {s, d} -> {[spec | s], d}
        {:dynamic, spec}, {s, d} -> {s, [spec | d]}
      end)

    %{static: Enum.reverse(statics), dynamic: Enum.reverse(dynamics)}
  end
end
