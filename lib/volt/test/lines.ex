defmodule Volt.Test.Lines do
  @moduledoc """
  Extracts source line numbers for JavaScript test declarations.

  Runtime collection owns JS semantics such as nested `describe` names and hooks.
  This module adds source locations with OXC so generated ExUnit tests can point
  at useful file lines without hand-parsing JavaScript.
  """

  @spec test_lines(String.t(), String.t()) :: {:ok, [pos_integer()]} | {:error, term()}
  def test_lines(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        {:ok, ast |> collect_test_starts() |> Enum.sort() |> Enum.map(&line(source, &1))}

      {:error, _} = error ->
        error
    end
  end

  defp collect_test_starts(ast) do
    {_ast, starts} =
      OXC.postwalk(ast, [], fn
        %{type: :call_expression, callee: callee, arguments: args} = node, starts
        when is_list(args) ->
          if test_callee?(callee) and test_call?(args) do
            {node, [node.start | starts]}
          else
            {node, starts}
          end

        node, starts ->
          {node, starts}
      end)

    starts
  end

  defp test_callee?(%{type: :identifier, name: name}) when name in ["test", "it"], do: true

  defp test_callee?(%{type: :member_expression, object: object, property: %{name: property}})
       when property in ["skip", "todo"] do
    test_callee?(object)
  end

  defp test_callee?(_), do: false

  defp test_call?([%{value: name} | _]) when is_binary(name), do: true
  defp test_call?([%{type: :template_literal, expressions: [], quasis: [_]} | _]), do: true
  defp test_call?(_), do: false

  defp line(source, start) do
    source
    |> binary_part(0, start)
    |> count_newlines(1)
  end

  defp count_newlines(<<>>, line), do: line
  defp count_newlines(<<?\n, rest::binary>>, line), do: count_newlines(rest, line + 1)
  defp count_newlines(<<_byte, rest::binary>>, line), do: count_newlines(rest, line)
end
