defmodule Mix.Tasks.Volt.TestTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Volt.Test.Sigils

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    Mix.Task.reenable("volt.test")
    Mix.Task.reenable("test")

    original_env = Application.get_all_env(:volt)
    tmp_dir = Path.join(System.tmp_dir!(), "volt-mix-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    :volt
    |> Application.get_all_env()
    |> Enum.each(fn {key, _value} -> Application.delete_env(:volt, key) end)

    on_exit(fn ->
      Mix.shell(previous_shell)
      Mix.Task.reenable("volt.test")
      Mix.Task.reenable("test")
      File.rm_rf!(tmp_dir)

      :volt
      |> Application.get_all_env()
      |> Enum.each(fn {key, _value} -> Application.delete_env(:volt, key) end)

      Enum.each(original_env, fn {key, value} -> Application.put_env(:volt, key, value) end)
    end)

    %{tmp_dir: tmp_dir}
  end

  test "reports when no JS tests are discovered", %{tmp_dir: tmp_dir} do
    Application.put_env(:volt, :test, root: tmp_dir, include: ["**/*.test.ts"])

    capture_io(fn ->
      Mix.Tasks.Volt.Test.run([])
    end)

    assert_received {:mix_shell, :info, ["No Volt JS/TS test files found"]}
  end

  test "runs discovered JS tests through generated ExUnit modules", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "math.test.ts", ~TS"""
    import { test, expect } from 'volt:test'

    test('adds', () => {
      expect(1 + 1).toBe(2)
    })
    """)

    Application.put_env(:volt, :test, root: tmp_dir, include: ["**/*.test.ts"])

    output =
      capture_io(fn ->
        Mix.Tasks.Volt.Test.run([])
      end)

    assert output =~ "Result: 1 passed"
  end

  test "dogfoods Volt's own TypeScript test core" do
    output =
      capture_io(fn ->
        Mix.Tasks.Volt.Test.run(["--root", "priv/ts", "--include", "test/core.test.ts"])
      end)

    assert output =~ "Result: 1 passed"
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end
end
