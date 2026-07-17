defmodule Volt.DevTest do
  use ExUnit.Case, async: false

  test "starts one supervised watcher per profile and asset root" do
    root = Path.expand("volt-dev-#{System.unique_integer([:positive])}", System.tmp_dir!())
    File.mkdir_p!(root)

    assert :ok = Volt.Dev.ensure_watcher(id: :default, root: root, tailwind: false)
    assert [{pid, _}] = Registry.lookup(Volt.Dev.WatcherRegistry, {:watcher, :default, root})

    on_exit(fn ->
      if Process.alive?(pid) do
        DynamicSupervisor.terminate_child(Volt.Dev.WatcherSupervisor, pid)
      end

      File.rm_rf!(root)
    end)

    assert Process.alive?(pid)
    assert :ok = Volt.Dev.ensure_watcher(id: :default, root: root, tailwind: false)
    assert [{^pid, _}] = Registry.lookup(Volt.Dev.WatcherRegistry, {:watcher, :default, root})

    assert :ok = Volt.Dev.ensure_watcher(id: :admin, root: root, tailwind: false)

    assert [{profile_pid, _}] =
             Registry.lookup(Volt.Dev.WatcherRegistry, {:watcher, :admin, root})

    on_exit(fn ->
      if Process.alive?(profile_pid) do
        DynamicSupervisor.terminate_child(Volt.Dev.WatcherSupervisor, profile_pid)
      end
    end)

    assert profile_pid != pid
  end
end
