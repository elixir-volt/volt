defmodule Volt.DevTest do
  use ExUnit.Case, async: false

  test "starts one supervised watcher per profile and asset root" do
    root = Path.join(System.tmp_dir!(), "volt-dev-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    assert {:ok, pid} = Volt.Dev.ensure_watcher(id: :default, root: root, tailwind: false)

    on_exit(fn ->
      if Process.alive?(pid) do
        DynamicSupervisor.terminate_child(Volt.Dev.WatcherSupervisor, pid)
      end

      File.rm_rf!(root)
    end)

    assert Process.alive?(pid)
    assert {:ok, ^pid} = Volt.Dev.ensure_watcher(id: :default, root: root, tailwind: false)

    assert {:ok, profile_pid} =
             Volt.Dev.ensure_watcher(id: :admin, root: root, tailwind: false)

    on_exit(fn ->
      if Process.alive?(profile_pid) do
        DynamicSupervisor.terminate_child(Volt.Dev.WatcherSupervisor, profile_pid)
      end
    end)

    assert profile_pid != pid
  end
end
