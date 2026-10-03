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
    with {:ok, ast} <- OXC.parse(source, filename),
         {:ok, groups} <- collect_test_groups(ast) do
      {:ok, lines(source, flatten_groups(groups))}
    end
  end

  # A group is `{anchor, starts}`: the offset of a test declaration and the
  # offsets of the tests it registers, in registration order. Post-order
  # traversal reaches the tests inside a `describe.each` body before the
  # `describe.each` call, which then folds their groups into one repeated group.
  defp collect_test_groups(ast) do
    {_ast, acc} =
      OXC.postwalk(ast, {:ok, []}, fn
        %{type: :call_expression, callee: callee, arguments: args} = node, {:ok, groups}
        when is_list(args) ->
          {node, add_test_group(node, callee, args, groups)}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp add_test_group(node, callee, args, groups) do
    cond do
      test_callee?(callee) and test_call?(args) ->
        {:ok, [{node.start, [node.start]} | groups]}

      each_callee?(callee, &test_callee?/1) and test_call?(args) ->
        with {:ok, count} <- case_count(callee) do
          {:ok, [{node.start, List.duplicate(node.start, count)} | groups]}
        end

      each_callee?(callee, &describe_callee?/1) ->
        with {:ok, count} <- case_count(callee) do
          {inner, outer} =
            Enum.split_with(groups, fn {anchor, _starts} ->
              anchor > node.start and anchor < node.end
            end)

          starts = inner |> flatten_groups() |> List.duplicate(count) |> Enum.concat()
          {:ok, [{node.start, starts} | outer]}
        end

      true ->
        {:ok, groups}
    end
  end

  defp flatten_groups(groups) do
    groups |> Enum.sort() |> Enum.flat_map(fn {_anchor, starts} -> starts end)
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
    do: {:ok, length(elements)}

  defp case_count(_each_call), do: {:error, :dynamic_cases}

  defp test_call?([%{value: name} | _]) when is_binary(name), do: true
  defp test_call?([%{type: :template_literal, expressions: [], quasis: [_]} | _]), do: true
  defp test_call?(_), do: false

  # Counts each newline once for all offsets. Counting from the start of the
  # source per test is quadratic and dominated the cost on large files.
  defp lines(source, starts) do
    newlines = for {offset, _length} <- :binary.matches(source, "\n"), do: offset

    {line_by_start, _rest, _line} =
      starts
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.reduce({%{}, newlines, 1}, fn start, {lines, newlines, line} ->
        {before, rest} = Enum.split_while(newlines, &(&1 < start))
        line = line + length(before)
        {Map.put(lines, start, line), rest, line}
      end)

    Enum.map(starts, &Map.fetch!(line_by_start, &1))
  end
end
