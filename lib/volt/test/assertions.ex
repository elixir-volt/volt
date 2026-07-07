defmodule Volt.Test.Assertions do
  @moduledoc """
  Converts Volt JavaScript test runner results into ExUnit assertions.
  """

  import ExUnit.Assertions

  @doc """
  Runs JavaScript-like sigils as Volt test assertions.

  This extends ExUnit's `assert/1` for `~JS`, `~TS`, `~JSX`, and `~TSX`
  snippets while delegating all other expressions to `ExUnit.Assertions.assert/1`.
  """
  defmacro assert(source)

  defmacro assert(source) do
    case js_sigil_extension(source) do
      nil ->
        quote do
          ExUnit.Assertions.assert(unquote(source))
        end

      extension ->
        assert_js_quote(source, [extension: extension], __CALLER__)
    end
  end

  @doc """
  Delegates to ExUnit's `assert/2`.
  """
  defmacro assert(source, message) do
    quote do
      ExUnit.Assertions.assert(unquote(source), unquote(message))
    end
  end

  @doc """
  Runs a JavaScript or TypeScript snippet as a Volt test assertion.

  The snippet body is wrapped in a single Volt `test(...)`. Top-level import
  declarations are preserved outside the wrapper so snippets can import app
  code while keeping assertions inline in ExUnit tests.
  """
  defmacro assert_js(source, opts \\ []) do
    assert_js_quote(source, maybe_put_sigil_extension(source, opts), __CALLER__)
  end

  defp assert_js_quote(source, opts, caller) do
    config = caller.module |> Module.get_attribute(:volt_test_config) |> Kernel.||([])
    config = Macro.escape(config)

    quote do
      Volt.Test.Assertions.__assert_js__(
        unquote(source),
        Keyword.merge(unquote(config), unquote(opts)),
        %{file: __ENV__.file, line: __ENV__.line, module: __MODULE__}
      )
    end
  end

  defp maybe_put_sigil_extension(source, opts) do
    case {Keyword.has_key?(opts, :extension), js_sigil_extension(source)} do
      {false, extension} when is_binary(extension) -> Keyword.put(opts, :extension, extension)
      _ -> opts
    end
  end

  defp js_sigil_extension({:sigil_JS, _meta, _args}), do: ".js"
  defp js_sigil_extension({:sigil_TS, _meta, _args}), do: ".ts"
  defp js_sigil_extension({:sigil_JSX, _meta, _args}), do: ".jsx"
  defp js_sigil_extension({:sigil_TSX, _meta, _args}), do: ".tsx"
  defp js_sigil_extension(_source), do: nil

  @doc false
  def __assert_js__(source, opts, caller), do: Volt.Test.Inline.assert!(source, opts, caller)

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
    IO.iodata_to_binary(["\nJS stacktrace:\n", Enum.intersperse(lines, "\n")])
  end

  defp clean_stack(stack) when is_binary(stack) do
    stack
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or framework_stack?(&1)))
  end

  defp clean_stack(_), do: []

  defp framework_stack?(line) do
    String.contains?(line, "/volt-test-runtime/") or
      String.contains?(line, "__voltRunTestModule") or
      String.contains?(line, "assertionError")
  end
end
