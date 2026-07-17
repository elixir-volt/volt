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
    tests = Enum.sort_by(test_module.tests, &test_description/1)

    assert length(tests) == 2

    assert Enum.map(tests, &test_description/1) == [
             "test math › adds",
             "test math › multiplies"
           ]

    for test <- tests do
      assert test_tag(test, :js) == true
      assert test_tag(test, :volt_file) == file
      assert test_tag(test, :volt_test_id) in [1, 2]
      assert test_tag(test, :file) == file
      assert test_tag(test, :line) in [4, 5]
      assert test_tag(test, :test_type) == :test
    end
  end

  test "file granularity registers and executes one ExUnit test per file", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "file-granularity.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('adds', () => expect(1 + 1).toBe(2))
      test('multiplies', () => expect(2 * 3).toBe(6))
      """)

    assert [module] =
             Volt.Test.ExUnit.install(
               root: tmp_dir,
               include: ["file-granularity.test.ts"],
               granularity: :file
             )

    assert [test] = module.__ex_unit__().tests
    assert test_description(test) == "test file-granularity.test.ts"
    assert test_tag(test, :js) == true
    assert test_tag(test, :volt_file) == file
    assert :ok = apply(module, test_name(test), [%{}])
  end

  test "file granularity tags browser modules", %{tmp_dir: tmp_dir} do
    file = write!(tmp_dir, "browser-file.test.ts", "test('browser', () => {})\n")

    assert [module] =
             Volt.Test.ExUnit.install(
               root: tmp_dir,
               include: ["browser-file.test.ts"],
               browser: true,
               granularity: :file
             )

    assert [test] = module.__ex_unit__().tests
    assert test_tag(test, :browser_js) == true
    assert test_tag(test, :volt_file) == file
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

    tests = Enum.sort_by(module.__ex_unit__().tests, &test_description/1)
    skipped = Enum.find(tests, &(test_description(&1) == "test skipped"))
    tagged = Enum.find(tests, &(test_description(&1) == "test tagged"))
    todo = Enum.find(tests, &(test_description(&1) == "test todo"))

    assert test_tag(skipped, :skip) == "Skipped"
    assert test_tag(todo, :skip) == "TODO"
    assert test_tag(tagged, :volt_tags) == ["slow", "browser"]
    assert test_tag(tagged, :volt_file) == file
  end

  test "generated ExUnit test functions execute a single JS test", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "single.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('passes', () => expect(40 + 2).toBe(42))
      """)

    assert [module] = Volt.Test.ExUnit.install(root: tmp_dir, include: ["single.test.ts"])
    [test] = module.__ex_unit__().tests

    assert :ok = apply(module, test_name(test), [%{}])
    assert file
  end

  test "install raises when a discovered JS test file defines no tests", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "empty.test.ts", "import { test } from 'volt:test'\n")

    assert_raise RuntimeError, ~r/did not define any tests/, fn ->
      Volt.Test.ExUnit.install(root: tmp_dir, include: ["empty.test.ts"])
    end
  end

  test "file granularity fails when a discovered JS test file defines no tests", %{
    tmp_dir: tmp_dir
  } do
    write!(tmp_dir, "empty-file.test.ts", "import { test } from 'volt:test'\n")

    assert [module] =
             Volt.Test.ExUnit.install(
               root: tmp_dir,
               include: ["empty-file.test.ts"],
               granularity: :file
             )

    [test] = module.__ex_unit__().tests

    assert_raise ExUnit.AssertionError, ~r/did not define any tests/, fn ->
      apply(module, test_name(test), [%{}])
    end
  end

  defp test_description(%ExUnit.Test{name: name}), do: Atom.to_string(name)
  defp test_description(test), do: Map.fetch!(test, :description)
  defp test_name(test), do: Map.fetch!(test, :name)

  defp test_tag(%{tags: tags}, key), do: Map.fetch!(tags, key)
  defp test_tag(test, key), do: Map.fetch!(test, key)

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
