defmodule Volt.Test.Assertions do
  @moduledoc """
  Converts Volt JavaScript test runner results into ExUnit assertions.
  """

  import ExUnit.Assertions

  @spec assert_passed!(map()) :: :ok
  def assert_passed!(%{"status" => "passed"}), do: :ok

  def assert_passed!(%{"tests" => tests} = result) when is_list(tests) do
    failures = Enum.filter(tests, &(&1["status"] == "failed"))

    case failures do
      [] -> flunk("Volt JS test file failed without failed test details: #{inspect(result)}")
      [failure | _] -> flunk(format_failure(failure, result))
    end
  end

  def assert_passed!(result) do
    flunk("Volt JS test file failed: #{inspect(result)}")
  end

  defp format_failure(failure, result) do
    error = failure["error"] || %{}

    [
      "#{result["file"]}: #{failure["fullName"] || failure["name"]}",
      "",
      error["message"] || inspect(error),
      expected_actual(error),
      stack(error)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  defp expected_actual(%{"expected" => expected, "actual" => actual}) do
    "\nexpected: #{inspect(expected)}\n     got: #{inspect(actual)}"
  end

  defp expected_actual(_), do: nil

  defp stack(%{"stack" => stack}) when is_binary(stack), do: "\nstacktrace:\n#{stack}"
  defp stack(_), do: nil
end
