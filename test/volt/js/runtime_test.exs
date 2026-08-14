defmodule Volt.JS.RuntimeTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Runtime

  setup do
    name = String.to_atom("volt_runtime_test_#{System.unique_integer([:positive])}")
    tmp_dir = Path.join(System.tmp_dir!(), Atom.to_string(name))

    on_exit(fn ->
      try do
        if pid = GenServer.whereis(name), do: Runtime.stop(pid)
      catch
        :exit, _reason -> :ok
      end

      File.rm_rf!(tmp_dir)
    end)

    %{name: name, tmp_dir: tmp_dir}
  end

  test "named runtimes reject mismatched options", %{name: name, tmp_dir: tmp_dir} do
    first_dir = Path.join(tmp_dir, "first")
    second_dir = Path.join(tmp_dir, "second")

    runtime = Runtime.ensure!(name: name, packages: %{}, install_dir: first_dir)

    assert is_pid(runtime.pid)

    assert_raise ArgumentError, ~r/already started with different options/, fn ->
      Runtime.ensure!(name: name, packages: %{}, install_dir: second_dir)
    end
  end

  test "named runtimes include package-owned lock contents in their signature", %{
    name: name,
    tmp_dir: tmp_dir
  } do
    install_dir = Path.join(tmp_dir, "runtime")
    lockfile = Path.join(tmp_dir, "npm.lock")
    File.mkdir_p!(tmp_dir)
    :ok = NPM.Lockfile.write(%{}, lockfile)

    runtime =
      Runtime.ensure!(
        name: name,
        packages: %{},
        lockfile: lockfile,
        install_dir: install_dir
      )

    assert is_pid(runtime.pid)
    File.write!(lockfile, File.read!(lockfile) <> "\n")

    assert_raise ArgumentError, ~r/already started with different options/, fn ->
      Runtime.ensure!(
        name: name,
        packages: %{},
        lockfile: lockfile,
        install_dir: install_dir
      )
    end
  end
end
