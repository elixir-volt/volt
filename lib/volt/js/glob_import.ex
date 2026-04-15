defmodule Volt.JS.GlobImport do
  @moduledoc """
  Transform `import.meta.glob()` calls into static import maps.

  Uses OXC AST to find calls, resolves glob patterns at build time,
  and patches the source with `OXC.patch_string/2`.

  ## Example

      // Source
      const modules = import.meta.glob('./pages/*.ts')

      // Transformed (lazy — default)
      const modules = {
        "./pages/home.ts": () => import("./pages/home.ts"),
        "./pages/about.ts": () => import("./pages/about.ts"),
      }

      // With { eager: true }
      import * as __glob_0 from "./pages/home.ts"
      import * as __glob_1 from "./pages/about.ts"
      const modules = {
        "./pages/home.ts": __glob_0,
        "./pages/about.ts": __glob_1,
      }
  """

  @doc """
  Transform `import.meta.glob()` calls in source code.

  `base_dir` is the directory of the file containing the glob call,
  used to resolve the glob pattern to actual files.
  """
  @spec transform(String.t(), String.t()) :: String.t()
  def transform(source, base_dir) do
    case OXC.parse(source, "glob.ts") do
      {:ok, ast} ->
        calls = collect_glob_calls(ast)
        if calls == [], do: source, else: apply_transforms(source, calls, base_dir)

      {:error, _} ->
        source
    end
  end

  defp collect_glob_calls(ast) do
    {_ast, calls} =
      OXC.postwalk(ast, [], fn
        %{
          type: :call_expression,
          callee: %{
            type: :member_expression,
            object: %{type: :meta_property},
            property: %{name: "glob"}
          },
          arguments: args
        } = node,
        acc ->
          case parse_glob_args(args) do
            {:ok, pattern, eager?} ->
              {node, [%{start: node.start, end: node.end, pattern: pattern, eager: eager?} | acc]}

            :skip ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.sort_by(calls, & &1.start)
  end

  defp parse_glob_args([%{type: :literal, value: pattern} | rest]) when is_binary(pattern) do
    eager? =
      case rest do
        [%{type: :object_expression, properties: props} | _] ->
          Enum.any?(props, fn
            %{key: %{name: "eager"}, value: %{value: true}} -> true
            _ -> false
          end)

        _ ->
          false
      end

    {:ok, pattern, eager?}
  end

  defp parse_glob_args(_), do: :skip

  defp apply_transforms(source, calls, base_dir) do
    {eager_calls, lazy_calls} = Enum.split_with(calls, & &1.eager)

    eager_preamble =
      eager_calls
      |> Enum.with_index()
      |> Enum.map(fn {call, i} ->
        files = resolve_glob(call.pattern, base_dir)
        {preamble_lines(files, i * 100), entries_eager(files, i * 100)}
      end)

    preamble =
      eager_preamble
      |> Enum.flat_map(fn {lines, _} -> lines end)
      |> Enum.join("\n")

    eager_patches =
      eager_calls
      |> Enum.zip(Enum.map(eager_preamble, fn {_, entries} -> entries end))
      |> Enum.map(fn {call, entries} ->
        %{start: call.start, end: call.end, change: "{\n#{entries}\n}"}
      end)

    lazy_patches =
      Enum.map(lazy_calls, fn call ->
        files = resolve_glob(call.pattern, base_dir)
        %{start: call.start, end: call.end, change: lazy_expansion(files)}
      end)

    patched = OXC.patch_string(source, eager_patches ++ lazy_patches)

    if preamble == "" do
      patched
    else
      preamble <> "\n" <> patched
    end
  end

  defp resolve_glob(pattern, base_dir) do
    Path.join(base_dir, pattern)
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&("./" <> Path.relative_to(&1, base_dir)))
  end

  defp lazy_expansion(files) do
    entries =
      Enum.map_join(files, ",\n", fn file ->
        "  \"#{file}\": () => import(\"#{file}\")"
      end)

    "{\n#{entries}\n}"
  end

  defp preamble_lines(files, offset) do
    files
    |> Enum.with_index(offset)
    |> Enum.map(fn {file, i} -> ~s(import * as __glob_#{i} from "#{file}") end)
  end

  defp entries_eager(files, offset) do
    files
    |> Enum.with_index(offset)
    |> Enum.map_join(",\n", fn {file, i} -> ~s(  "#{file}": __glob_#{i}) end)
  end
end
