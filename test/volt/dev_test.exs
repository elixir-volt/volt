defmodule Volt.DevTest do
  use ExUnit.Case, async: false

  @tag :tmp_dir
  test "explicit sessions reject conflicting roots and stop clears state", %{tmp_dir: root} do
    session = make_ref()
    opts = [session: session, root: root, tailwind: false]
    assert {:ok, pid} = Volt.Dev.start(opts)
    on_exit(fn -> Volt.Dev.stop(session) end)
    assert {:ok, ^pid} = Volt.Dev.start(opts)

    assert {:error, :session_configuration_conflict} =
             Volt.Dev.start(Keyword.put(opts, :root, Path.join(root, "other")))

    Volt.Cache.put("/app.js", 1, %Volt.DevServer.CacheEntry{code: "session"}, session)
    Volt.HMR.ImportGraph.update("/app.js", ["./child.js"], session)
    Volt.HMR.ModuleGraph.update_module("/app.js", "/app.js", "/app.js", [], session: session)
    assert :ok = Volt.Dev.stop(session)
    refute Process.alive?(pid)
    assert Volt.Cache.get_file("/app.js", session) == nil
    assert Volt.HMR.ImportGraph.imports_of("/app.js", session) == []
    assert Volt.HMR.ModuleGraph.get_by_url("/app.js", session) == nil
    assert :ok = Volt.Dev.stop(session)
  end

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
