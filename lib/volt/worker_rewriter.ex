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

  @doc false
  @spec extract_specifier(map()) :: {:ok, String.t(), non_neg_integer(), non_neg_integer()} | nil
  def extract_specifier(%{
        type: "NewExpression",
        callee: %{type: "Identifier", name: "URL"},
        arguments: [
          source_node,
          %{type: "MemberExpression", property: %{type: "Identifier", name: "url"}} | _
        ]
      }) do
    extract_string_value(source_node)
  end

  def extract_specifier(_), do: nil

  defp extract_string_value(%{value: spec, start: s, end: e})
       when is_binary(spec) and is_integer(s) and is_integer(e),
       do: {:ok, spec, s, e}

  defp extract_string_value(%{type: "StringLiteral", value: spec, start: s, end: e})
       when is_binary(spec) and is_integer(s) and is_integer(e),
       do: {:ok, spec, s, e}

  defp extract_string_value(_), do: nil

  defp collect_worker_patches(ast, rewrite_fn) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{
          type: "NewExpression",
          callee: %{type: "Identifier", name: worker_type},
          arguments: [first_arg | _]
        } = node,
        patches
        when worker_type in ["Worker", "SharedWorker"] ->
          case extract_specifier(first_arg) do
            {:ok, specifier, s, e} ->
              case rewrite_fn.(specifier) do
                {:rewrite, new} -> {node, [%{start: s, end: e, change: "'#{new}'"} | patches]}
                :keep -> {node, patches}
              end

            nil ->
              {node, patches}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end
end
