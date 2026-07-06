defmodule Volt.Test.AssertionsTest do
  use ExUnit.Case, async: true

  alias Volt.Test.Result

  test "formats assertion failures with expected actual and useful JS stack" do
    result = %Result{
      file: "assets/js/math.test.ts",
      status: :failed,
      failed: 1,
      total: 1,
      tests: [
        %Result.Test{
          name: "adds",
          full_name: "math › adds",
          status: :failed,
          error: %Result.SerializedError{
            name: "AssertionError",
            message: "Expected 1 to be 2",
            expected: 2,
            actual: 1,
            stack: """
                at assertionError (/tmp/volt-test-runtime/runtime/core.ts:129:20)
                at toBe (/tmp/volt-test-runtime/runtime/core.ts:53:69)
                at <anonymous> (<input>:4:13)
                at __voltRunTestModule (/tmp/volt-test-runtime/runtime/core.ts:100:21)
            """
          }
        }
      ]
    }

    error =
      assert_raise ExUnit.AssertionError, fn ->
        Volt.Test.Assertions.assert_passed!(result)
      end

    message = Exception.message(error)

    assert message =~ "assets/js/math.test.ts"
    assert message =~ "math › adds"
    assert message =~ "Expected 1 to be 2"
    assert message =~ "expected: 2"
    assert message =~ "got: 1"
    assert message =~ "JS stacktrace:"
    assert message =~ "<input>:4:13"
    refute message =~ "assertionError"
    refute message =~ "__voltRunTestModule"
  end

  test "reports missing failure details clearly" do
    assert_raise ExUnit.AssertionError, ~r/failed without failed test details/, fn ->
      Volt.Test.Assertions.assert_passed!(%Result{status: :failed, tests: []})
    end
  end
end
