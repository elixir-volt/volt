defmodule Volt.ImportRewriter do
  @moduledoc """
  Rewrite import specifiers in compiled JS output using AST positions.

  Turns bare specifiers (`'vue'`) into dev server paths (`'/@vendor/vue.js'`)
  and resolves relative imports to absolute URL paths. Uses `OXC.postwalk/3`
  to find import nodes and `OXC.patch_string/2` to splice replacements
  at exact byte offsets — no regex, no reformatting.
  """

  @doc """
  Rewrite import specifiers in JavaScript source code.

  The `rewrite_fn` receives each import specifier string and returns
  either `{:rewrite, new_specifier}` or `:keep`.

  ## Examples

      iex> source = "import { ref } from 'vue'\\nimport a from './utils'"
      iex> Volt.ImportRewriter.rewrite(source, "test.ts", fn
      ...>   "vue" -> {:rewrite, "/@vendor/vue.js"}
      ...>   _ -> :keep
      ...> end)
      {:ok, "import { ref } from '/@vendor/vue.js'\\nimport a from './utils'"}
  """
  @spec rewrite(String.t(), String.t(), (String.t() -> {:rewrite, String.t()} | :keep)) ::
          {:ok, String.t()} | {:error, term()}
  def rewrite(source, filename, rewrite_fn) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        patches = collect_import_patches(ast, rewrite_fn)
        {:ok, OXC.patch_string(source, patches)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Like `rewrite/3` but raises on errors."
  @spec rewrite!(String.t(), String.t(), (String.t() -> {:rewrite, String.t()} | :keep)) ::
          String.t()
  def rewrite!(source, filename, rewrite_fn) do
    case rewrite(source, filename, rewrite_fn) do
      {:ok, result} -> result
      {:error, errors} -> raise "Import rewrite error: #{inspect(errors)}"
    end
  end

  @doc """
  Rewrite import specifiers using a map of `old → new`.

  Convenience wrapper around `rewrite/3` for static rewrites.

  ## Examples

      iex> source = "import { ref } from 'vue'\\nimport { h } from 'preact'"
      iex> Volt.ImportRewriter.rewrite_map(source, "test.ts", %{
      ...>   "vue" => "/@vendor/vue.js",
      ...>   "preact" => "/@vendor/preact.js"
      ...> })
      {:ok, "import { ref } from '/@vendor/vue.js'\\nimport { h } from '/@vendor/preact.js'"}
  """
  @spec rewrite_map(String.t(), String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t()} | {:error, term()}
  def rewrite_map(source, filename, rewrites) when is_map(rewrites) do
    rewrite(source, filename, fn specifier ->
      case Map.fetch(rewrites, specifier) do
        {:ok, new} -> {:rewrite, new}
        :error -> :keep
      end
    end)
  end

  defp collect_import_patches(ast, rewrite_fn) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: :import_declaration, source: source_node} = node, patches ->
          {node, maybe_patch(source_node, rewrite_fn, patches)}

        %{type: :export_named_declaration, source: source_node} = node, patches
        when is_map(source_node) ->
          {node, maybe_patch(source_node, rewrite_fn, patches)}

        %{type: :export_all_declaration, source: source_node} = node, patches ->
          {node, maybe_patch(source_node, rewrite_fn, patches)}

        %{type: :import_expression, source: %{type: :literal, value: spec} = source_node} = node,
        patches
        when is_binary(spec) ->
          {node, maybe_patch(source_node, rewrite_fn, patches)}

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp maybe_patch(%{value: specifier, start: s, end: e}, rewrite_fn, patches)
       when is_binary(specifier) and is_integer(s) and is_integer(e) do
    case rewrite_fn.(specifier) do
      {:rewrite, new_specifier} ->
        quote_char = "'"
        [%{start: s, end: e, change: "#{quote_char}#{new_specifier}#{quote_char}"} | patches]

      :keep ->
        patches
    end
  end

  defp maybe_patch(_, _, patches), do: patches
end
