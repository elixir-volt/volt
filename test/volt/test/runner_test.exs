defmodule Volt.Test.RunnerTest do
  use ExUnit.Case, async: false

  import Volt.Test.Sigils

  alias Volt.Test.Result
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
              %Result.Metadata{full_name: "suite › first", line: 4},
              %Result.Metadata{full_name: "suite › second", line: 6}
            ]} = Runner.collect_file(path)
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
              %Result.Metadata{mode: :skip, skip_reason: "Skipped"},
              %Result.Metadata{mode: :todo, skip_reason: "TODO"},
              %Result.Metadata{mode: :run, tags: ["slow"]}
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
            %Result{
              status: :passed,
              skipped: 1,
              tests: [%Result.Test{status: :skipped, skip_reason: "not today"}]
            }} = Runner.run_file(path)
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

    assert {:ok, %Result{status: :passed, total: 1, failed: 0, tests: [test]}} =
             Runner.run_file(path)

    assert test.full_name == "math › adds numbers"
    assert test.status == :passed
  end

  test "keeps durations monotonic when a test replaces Date.now", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "fake_clock.test.js", ~JS"""
      test('replaces the wall clock', () => {
        Date.now = () => 0
      })
      """)

    assert {:ok, %Result{duration: duration, tests: [%Result.Test{duration: test_duration}]}} =
             Runner.run_file(path)

    assert duration >= 0
    assert test_duration >= 0
  end

  test "loads setup files before the test module", %{tmp_dir: tmp_dir} do
    setup_path =
      write!(tmp_dir, "setup.ts", ~TS"""
      globalThis.setupValue = 42
      """)

    path =
      write!(tmp_dir, "setup_file.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('uses setup state', () => {
        expect(globalThis.setupValue).toBe(42)
      })
      """)

    config = Volt.Test.Config.read(root: tmp_dir, setup_files: [Path.basename(setup_path)])

    assert {:ok, %Result{status: :passed, total: 1}} = Runner.run_file(path, config: config)
  end

  test "returns structured assertion failures", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "failure.test.js", ~JS"""
      test('fails clearly', () => {
        expect({ value: 1 }).toEqual({ value: 2 })
      })
      """)

    assert {:ok, %Result{status: :failed, failed: 1, tests: [test]}} = Runner.run_file(path)

    assert test.status == :failed
    assert test.error.name == "AssertionError"
    assert test.error.message =~ "to equal"
    assert test.error.expected == %{"value" => 2}
    assert test.error.actual == %{"value" => 1}
  end

  test "returns structured errors without assertion details", %{tmp_dir: tmp_dir} do
    path =
      write!(tmp_dir, "error.test.js", ~JS"""
      test('throws an error', () => {
        throw new TypeError('not a function')
      })
      """)

    assert {:ok, %Result{status: :failed, failed: 1, tests: [test]}} = Runner.run_file(path)

    assert %Result.SerializedError{
             name: "TypeError",
             message: "not a function",
             expected: nil,
             actual: nil
           } = test.error
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

    assert {:ok, %Result{status: :passed, total: 1, failed: 0}} = Runner.run_file(path)
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

    assert {:ok, %Result{status: :passed, total: 1, failed: 0}} = Runner.run_file(path)
  end

  defp write!(root, path, contents) do
    path = Path.expand(path, root)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
