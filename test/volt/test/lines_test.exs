defmodule Volt.Test.LinesTest do
  use ExUnit.Case, async: true

  import Volt.Test.Sigils

  test "extracts test declaration line numbers with OXC" do
    source = ~TS"""
    import { describe, test, it } from 'volt:test'

    describe('math', () => {
      test('adds', () => {})

      it.skip('multiplies', () => {})
      test.todo('subtracts')
    })
    """

    assert Volt.Test.Lines.test_lines(source, "math.test.ts") == {:ok, [4, 6, 7]}
  end

  test "ignores non-test calls" do
    source = ~TS"""
    const helper = { test() {} }
    helper.test('not a test')
    test(dynamicName, () => {})
    """

    assert Volt.Test.Lines.test_lines(source, "helper.test.ts") == {:ok, []}
  end
end
