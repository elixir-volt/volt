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

  test "repeats lines for each-table cases in registration order" do
    source = ~TS"""
    import { describe, test } from 'volt:test'

    test.each([
      [1, 2],
      [2, 3],
      [3, 4]
    ])('adds %d', () => {})

    describe.each(['a', 'b'])('suite %s', () => {
      test('first', () => {})
      test('second', () => {})
    })

    test('after', () => {})
    """

    assert Volt.Test.Lines.test_lines(source, "each.test.ts") ==
             {:ok, [3, 3, 3, 10, 11, 10, 11, 14]}
  end

  test "reports each-tables whose cases are not an array literal" do
    source = ~TS"""
    const cases = [1, 2]
    test.each(cases)('case %d', () => {})
    """

    assert Volt.Test.Lines.test_lines(source, "dynamic.test.ts") == {:error, :dynamic_cases}
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
