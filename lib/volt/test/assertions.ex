defmodule Volt.Test.Assertions do
  @moduledoc """
  Converts Volt JavaScript test runner results into ExUnit assertions.
  """

  import ExUnit.Assertions

  @spec assert_passed!(Volt.Test.Result.t()) :: :ok
  def assert_passed!(%Volt.Test.Result{status: :passed}), do: :ok

  def assert_passed!(%Volt.Test.Result{tests: tests} = result) when is_list(tests) do
    failures = Enum.filter(tests, &(&1.status == :failed))

    case failures do
      [] -> flunk("Volt JS test file failed without failed test details: #{inspect(result)}")
      [failure | _] -> flunk(format_failure(failure, result, length(failures)))
    end
  end

  def assert_passed!(result) do
    flunk("Volt JS test file failed: #{inspect(result)}")
  end

  defp format_failure(failure, result, failure_count) do
    error = failure.error || %Volt.Test.Result.SerializedError{message: inspect(failure)}
    stack = clean_stack(error.stack)

    [
      heading(result, failure, failure_count),
      "",
      error.message || inspect(error),
      expected_actual(error),
      stack(stack)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  defp heading(result, failure, failure_count) do
    count =
      case failure_count do
        1 -> "1 JS test failed"
        n -> "#{n} JS tests failed; showing first failure"
      end

    "#{count}\n#{result.file}: #{failure.full_name || failure.name}"
  end

  defp expected_actual(%Volt.Test.Result.SerializedError{expected: expected, actual: actual})
       when not is_nil(expected) and not is_nil(actual) do
    "\nexpected: #{inspect(expected)}\n     got: #{inspect(actual)}"
  end

  defp expected_actual(%Volt.Test.Result.SerializedError{}), do: nil

  defp stack([]), do: nil

  defp stack(lines) do
    "\nJS stacktrace:\n" <> Enum.join(lines, "\n")
  end

  defp clean_stack(stack) when is_binary(stack) do
    stack
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&framework_stack?/1)
  end

  defp clean_stack(_), do: []

  defp framework_stack?(line) do
    String.contains?(line, "/volt-test-runtime/") or
      String.contains?(line, "__voltRunTestModule") or
      String.contains?(line, "assertionError")
  end
end
