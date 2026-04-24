defmodule Volt.JS.PrebundleEntry do
  @moduledoc false

  def source({:proxy, _filename, opts}) do
    code =
      opts
      |> Keyword.get(:imports, [])
      |> Enum.map_join("\n", &import_statement/1)
      |> append_lines(export_statements(Keyword.get(opts, :exports, [])))

    OXC.parse!(code, "prebundle-entry.js")
    code
  end

  defp import_statement(%{default: name, from: specifier}) do
    "import #{identifier!(name)} from #{literal!(specifier)};"
  end

  defp export_statements(exports) do
    Enum.map(exports, fn
      %{default: expression} ->
        "export default #{expression!(expression)};"

      %{members: members} ->
        Enum.map_join(members, "\n", fn {name, expression} ->
          "export const #{identifier!(name)} = #{expression!(expression)};"
        end)

      %{named_from: specifier, names: names} ->
        names = Enum.map_join(names, ", ", &export_name!/1)
        "export { #{names} } from #{literal!(specifier)};"

      %{all_from: specifier} ->
        "export * from #{literal!(specifier)};"
    end)
  end

  defp append_lines("", lines), do: Enum.join(lines, "\n") <> "\n"
  defp append_lines(prefix, lines), do: prefix <> "\n" <> Enum.join(lines, "\n") <> "\n"

  defp export_name!({name, as}) do
    "#{identifier!(name)} as #{identifier!(as)}"
  end

  defp export_name!(name), do: identifier!(name)

  defp identifier!(name) when is_binary(name) do
    if Regex.match?(~r/^[A-Za-z_$][A-Za-z0-9_$]*$/, name) do
      name
    else
      raise ArgumentError, "invalid JavaScript identifier: #{inspect(name)}"
    end
  end

  defp literal!(value) when is_binary(value) do
    :json.encode(value)
  end

  defp expression!(expression) when is_binary(expression) do
    OXC.parse!("const __volt_expression = #{expression};", "prebundle-expression.js")
    expression
  end
end
