defmodule Volt.Test.ImportsTest do
  use ExUnit.Case, async: true

  import Volt.Test.Sigils

  test "strips volt:test import declarations" do
    source = ~TS"""
    import { describe, test, expect } from "volt:test"

    describe("math", () => {
      test("adds", () => expect(1 + 1).toBe(2))
    })
    """

    assert {:ok, rewritten} = Volt.Test.Imports.strip(source, "math.test.ts")

    refute rewritten =~ "volt:test"
    assert rewritten =~ "describe(\"math\""
  end

  test "strips side-effect browser test imports" do
    source = ~TS"""
    import "volt:test/browser"
    test("browser", () => {})
    """

    assert {:ok, rewritten} = Volt.Test.Imports.strip(source, "browser.test.ts")

    refute rewritten =~ "volt:test/browser"
    assert rewritten =~ "test(\"browser\""
  end

  test "keeps non-test imports" do
    source = ~TS"""
    import { ref } from "vue"
    test("uses vue", () => expect(ref).toBe(ref))
    """

    assert {:ok, ^source} = Volt.Test.Imports.strip(source, "component.test.ts")
  end

  test "returns parse errors" do
    assert {:error, errors} = Volt.Test.Imports.strip("const = ;", "broken.test.ts")
    assert is_list(errors)
  end
end
