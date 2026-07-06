defmodule Volt.Test.ExUnitTest do
  use ExUnit.Case, async: false

  import Volt.Test.Sigils

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-test-ex-unit-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "install registers one ExUnit test per JS test", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "math.test.ts", ~TS"""
      import { describe, test, expect } from 'volt:test'

      describe('math', () => {
        test('adds', () => expect(1 + 1).toBe(2))
        test('multiplies', () => expect(2 * 3).toBe(6))
      })
      """)

    assert [module] = Volt.Test.ExUnit.install(root: tmp_dir, include: ["math.test.ts"])
    assert Code.ensure_loaded?(module)

    test_module = module.__ex_unit__()
    tests = Enum.sort_by(test_module.tests, & &1.description)

    assert length(tests) == 2
    assert Enum.map(tests, & &1.description) == ["test math › adds", "test math › multiplies"]

    for test <- tests do
      assert test.tags.js == true
      assert test.tags.volt_file == file
      assert test.tags.volt_test_id in [1, 2]
      assert test.tags.file == file
      assert test.tags.line in [4, 5]
      assert test.tags.test_type == :test
    end
  end

  test "install maps JS skip todo and tags to ExUnit tags", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "modifiers.test.ts", ~TS"""
      import { test } from 'volt:test'

      test.skip('skipped', () => {})
      test.todo('todo')
      test('tagged', { tags: ['slow', 'browser'] }, () => {})
      """)

    assert [module] = Volt.Test.ExUnit.install(root: tmp_dir, include: ["modifiers.test.ts"])

    tests = Enum.sort_by(module.__ex_unit__().tests, & &1.description)
    skipped = Enum.find(tests, &(&1.description == "test skipped"))
    tagged = Enum.find(tests, &(&1.description == "test tagged"))
    todo = Enum.find(tests, &(&1.description == "test todo"))

    assert skipped.tags.skip == "Skipped"
    assert todo.tags.skip == "TODO"
    assert tagged.tags.volt_tags == ["slow", "browser"]
    assert tagged.tags.volt_file == file
  end

  test "generated ExUnit test functions execute a single JS test", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "single.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('passes', () => expect(40 + 2).toBe(42))
      """)

    assert [module] = Volt.Test.ExUnit.install(root: tmp_dir, include: ["single.test.ts"])
    [%ExUnit.Test{name: name}] = module.__ex_unit__().tests

    assert :ok = apply(module, name, [%{}])
    assert file
  end

  test "install raises when a discovered JS test file defines no tests", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "empty.test.ts", "import { test } from 'volt:test'\n")

    assert_raise RuntimeError, ~r/did not define any tests/, fn ->
      Volt.Test.ExUnit.install(root: tmp_dir, include: ["empty.test.ts"])
    end
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
