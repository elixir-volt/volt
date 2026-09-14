defmodule Volt.JS.PrebundleEntry do
  @moduledoc """
  Generates synthetic JavaScript entry modules for vendor prebundling.

  Statements are assembled through OXC templates, literal replacement, and
  parser validation so plugin-provided prebundle entries cannot accidentally
  produce malformed JavaScript syntax.
  """

  def source({:proxy, _filename, opts}) do
    code =
      opts
      |> Keyword.get(:imports, [])
      |> Enum.map(&import_statement/1)
      |> Enum.intersperse("\n")
      |> append_lines(export_statements(Keyword.get(opts, :exports, [])))

    case OXC.parse!(code, "prebundle-entry.js") do
      _ast -> code
    end
  end

  defp import_statement(%Volt.JS.PrebundleEntry.Import{default: name, from: specifier}) do
    "import $name from \"__specifier__\";"
    |> OXC.parse!("prebundle-import.js")
    |> OXC.bind(name: identifier!(name))
    |> Volt.JS.AST.replace_literal("__specifier__", specifier)
    |> OXC.codegen!()
    |> String.trim()
  end

  defp export_statements(exports) do
    Enum.map(exports, fn
      %Volt.JS.PrebundleEntry.Export{default: expression} when not is_nil(expression) ->
        export_default_statement(expression)

      %Volt.JS.PrebundleEntry.Export{members: members} when not is_nil(members) ->
        members
        |> Enum.map(fn {name, expression} -> export_member_statement(name, expression) end)
        |> Enum.intersperse("\n")

      %Volt.JS.PrebundleEntry.Export{named_from: specifier, names: names}
      when not is_nil(specifier) ->
        names = names |> Enum.map(&export_name!/1) |> Enum.intersperse(", ")

        ["export { ", names, " } from \"__specifier__\";"]
        |> OXC.parse!("prebundle-export-named.js")
        |> Volt.JS.AST.replace_literal("__specifier__", specifier)
        |> OXC.codegen!()
        |> String.trim()

      %Volt.JS.PrebundleEntry.Export{all_from: specifier} when not is_nil(specifier) ->
        export_all_statement(specifier)
    end)
  end

  defp append_lines([], lines), do: [join_lines(lines), "\n"]

  defp append_lines(prefix, lines), do: [prefix, "\n", join_lines(lines), "\n"]

  defp join_lines(lines), do: Enum.intersperse(lines, "\n")

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

  defp export_default_statement(expression) do
    "export default $expression;"
    |> OXC.parse!("prebundle-export-default.js")
    |> OXC.bind(expression: {:expr, expression!(expression)})
    |> OXC.codegen!()
    |> String.trim()
  end

  defp export_member_statement(name, expression) do
    "export const $name = $expression;"
    |> OXC.parse!("prebundle-export-member.js")
    |> OXC.bind(name: identifier!(name), expression: {:expr, expression!(expression)})
    |> OXC.codegen!()
    |> String.trim()
  end

  defp export_all_statement(specifier) do
    "export * from \"__specifier__\";"
    |> OXC.parse!("prebundle-export-all.js")
    |> Volt.JS.AST.replace_literal("__specifier__", specifier)
    |> OXC.codegen!()
    |> String.trim()
  end

  defp expression!(expression) when is_binary(expression) do
    OXC.parse!("const __volt_expression = #{expression};", "prebundle-expression.js")
    expression
  end
end
