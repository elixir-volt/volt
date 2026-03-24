defmodule Volt.WorkerRewriter do
  @moduledoc false

  @spec rewrite(String.t(), String.t(), (String.t() -> {:rewrite, String.t()} | :keep)) ::
          {:ok, String.t()} | {:error, term()}
  def rewrite(source, filename, rewrite_fn) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        patches = collect_worker_patches(ast, rewrite_fn)
        if patches == [], do: {:ok, source}, else: {:ok, OXC.patch_string(source, patches)}

      {:error, _} = error ->
        error
    end
  end

  defp collect_worker_patches(ast, rewrite_fn) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: "NewExpression", callee: %{type: "Identifier", name: worker_type}, arguments: [first_arg | _]} = node, patches
        when worker_type in ["Worker", "SharedWorker"] ->
          {node, maybe_patch_worker(first_arg, rewrite_fn, patches)}

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp maybe_patch_worker(
         %{type: "NewExpression", callee: %{type: "Identifier", name: "URL"}, arguments: [source_node, %{type: "MetaProperty"} | _]},
         rewrite_fn,
         patches
       ) do
    maybe_patch_string(source_node, rewrite_fn, patches)
  end

  defp maybe_patch_worker(_, _, patches), do: patches

  defp maybe_patch_string(%{value: specifier, start: s, end: e}, rewrite_fn, patches)
       when is_binary(specifier) and is_integer(s) and is_integer(e) do
    case rewrite_fn.(specifier) do
      {:rewrite, new_specifier} ->
        [%{start: s, end: e, change: "'#{new_specifier}'"} | patches]

      :keep ->
        patches
    end
  end

  defp maybe_patch_string(_, _, patches), do: patches
end
