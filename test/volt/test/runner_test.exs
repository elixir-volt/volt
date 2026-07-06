defmodule Volt.Test.RunnerTest do
  use ExUnit.Case, async: false

  import Volt.Test.Sigils

  alias Volt.Test.Runner

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-test-runner-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "collects JS test metadata with source lines", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "collect.test.ts", ~TS"""
      import { describe, test } from 'volt:test'

      describe('suite', () => {
        test('first', () => {})

        test('second', () => {})
      })
      """)

    assert {:ok,
            [
              %{"fullName" => "suite › first", "line" => 4},
              %{"fullName" => "suite › second", "line" => 6}
            ]} =
             Runner.collect_file(path)
  end

  test "collects skip todo and tag metadata", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "modifiers.test.ts", ~TS"""
      import { test, it } from 'volt:test'

      test.skip('skipped', () => {})
      it.todo('todo')
      test('tagged', { tags: ['slow'] }, () => {})
      """)

    assert {:ok,
            [
              %{"mode" => "skip", "skipReason" => "Skipped"},
              %{"mode" => "todo", "skipReason" => "TODO"},
              %{"mode" => "run", "tags" => ["slow"]}
            ]} = Runner.collect_file(path)
  end

  test "skips tests dynamically from context", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "dynamic_skip.test.ts", ~TS"""
      import { test } from 'volt:test'

      test('dynamic skip', ({ skip }) => {
        skip('not today')
        throw new Error('should not run')
      })
      """)

    assert {:ok,
            %{
              "status" => "passed",
              "skipped" => 1,
              "tests" => [%{"status" => "skipped", "skipReason" => "not today"}]
            }} =
             Runner.run_file(path)
  end

  test "runs passing JavaScript tests", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "math.test.js", ~JS"""
      import { describe, test, expect } from 'volt:test'

      describe('math', () => {
        test('adds numbers', () => {
          expect(1 + 2).toBe(3)
        })
      })
      """)

    assert {:ok, %{"status" => "passed", "total" => 1, "failed" => 0, "tests" => [test]}} =
             Runner.run_file(path)

    assert test["fullName"] == "math › adds numbers"
    assert test["status"] == "passed"
  end

  test "returns structured assertion failures", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "failure.test.js", ~JS"""
      test('fails clearly', () => {
        expect({ value: 1 }).toEqual({ value: 2 })
      })
      """)

    assert {:ok, %{"status" => "failed", "failed" => 1, "tests" => [test]}} =
             Runner.run_file(path)

    assert test["status"] == "failed"
    assert test["error"]["name"] == "AssertionError"
    assert test["error"]["message"] =~ "to equal"
    assert test["error"]["expected"] == %{"value" => 2}
    assert test["error"]["actual"] == %{"value" => 1}
  end

  test "runs tests that import relative modules", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "math.ts", ~TS"""
    export function add(left: number, right: number) {
      return left + right
    }
    """)

    path =
      write!(tmp_dir, "math_import.test.ts", ~TS"""
      import { test, expect } from 'volt:test'
      import { add } from './math'

      test('uses a relative module', () => {
        expect(add(20, 22)).toBe(42)
      })
      """)

    assert {:ok, %{"status" => "passed", "total" => 1, "failed" => 0}} = Runner.run_file(path)
  end

  test "awaits async tests and hooks", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "async.test.ts", ~TS"""
      let value = 0

      beforeEach(async () => {
        value = await Promise.resolve(41)
      })

      test('awaits promises', async () => {
        const result: number = await Promise.resolve(value + 1)
        expect(result).toBe(42)
      })
      """)

    assert {:ok, %{"status" => "passed", "total" => 1, "failed" => 0}} = Runner.run_file(path)
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
