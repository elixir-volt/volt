defmodule Volt.Test.Lines do
  @moduledoc """
  Extracts source line numbers for JavaScript test declarations.

  Runtime collection owns JS semantics such as nested `describe` names and hooks.
  This module adds source locations with OXC so generated ExUnit tests can point
  at useful file lines without hand-parsing JavaScript.
  """

  @doc """
  Return the source line of every test in `source`, in the order the runtime
  registers them.

  `test.each` and `describe.each` register one test per case, so their lines
  repeat once per case. Returns `{:error, :dynamic_cases}` when the cases are
  not an array literal and the number of tests cannot be read from the source.
  """
  @spec test_lines(String.t(), String.t()) :: {:ok, [pos_integer()]} | {:error, term()}
  def test_lines(source, filename) do
    with {:ok, ast} <- OXC.parse(source, filename) do
      {:ok, ast |> test_starts() |> Enum.map(&line(source, &1))}
    end
  catch
    :dynamic_cases -> {:error, :dynamic_cases}
  end

  defp test_starts(%{type: :call_expression, callee: callee, arguments: args} = node)
       when is_list(args) do
    cond do
      test_callee?(callee) and test_call?(args) ->
        [node.start]

      each_callee?(callee, &test_callee?/1) and test_call?(args) ->
        List.duplicate(node.start, case_count(callee))

      each_callee?(callee, &describe_callee?/1) ->
        args |> test_starts() |> List.duplicate(case_count(callee)) |> Enum.concat()

      true ->
        child_starts(node)
    end
  end

  defp test_starts(node) when is_map(node), do: child_starts(node)
  defp test_starts(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &test_starts/1)
  defp test_starts(_other), do: []

  # Children in source order, which is the order the runtime runs them in.
  defp child_starts(node) do
    node
    |> Map.values()
    |> Enum.flat_map(&List.wrap/1)
    |> Enum.filter(&match?(%{start: start} when is_integer(start), &1))
    |> Enum.sort_by(& &1.start)
    |> Enum.flat_map(&test_starts/1)
  end

  defp test_callee?(%{type: :identifier, name: name}) when name in ["test", "it"], do: true

  defp test_callee?(%{type: :member_expression, object: object, property: %{name: property}})
       when property in ["skip", "todo"] do
    test_callee?(object)
  end

  defp test_callee?(_), do: false

  defp describe_callee?(%{type: :identifier, name: "describe"}), do: true

  defp describe_callee?(%{type: :member_expression, object: object, property: %{name: property}})
       when property in ["skip", "todo"] do
    describe_callee?(object)
  end

  defp describe_callee?(_), do: false

  # `test.each(cases)` and `describe.each(cases)`, whose result is then called
  # with the name and body.
  defp each_callee?(
         %{
           type: :call_expression,
           callee: %{type: :member_expression, object: object, property: %{name: "each"}}
         },
         base?
       ),
       do: base?.(object)

  defp each_callee?(_callee, _base?), do: false

  defp case_count(%{arguments: [%{type: :array_expression, elements: elements}]}),
    do: length(elements)

  defp case_count(_each_call), do: throw(:dynamic_cases)

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
