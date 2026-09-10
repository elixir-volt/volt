defmodule Volt.DevTest do
  use ExUnit.Case, async: false

  @tag :tmp_dir
  test "explicit compatibility sink is written by the session-owned worker", %{tmp_dir: root} do
    source = Path.join(root, "app.css")
    File.write!(source, ".sink { color: red }")
    sink = Path.join(root, "static")
    session = make_ref()

    assert {:ok, watcher} =
             Volt.Dev.start(
               session: session,
               root: root,
               tailwind: true,
               tailwind_css: source,
               tailwind_name: "site",
               tailwind_sources: [],
               tailwind_sink: sink
             )

    on_exit(fn -> Volt.Dev.stop(session) end)
    tables = :sys.get_state(watcher).tables
    assert {:ok, css} = Volt.Tailwind.Worker.stylesheet(tables.stylesheet_worker)
    assert File.read!(Path.join(sink, "site.css")) == css
    assert :sys.get_state(watcher).tailwind_outdir == sink
  end

  @tag :tmp_dir
  test "Tailwind contexts are isolated and released with explicit sessions", %{tmp_dir: root} do
    a = make_ref()
    b = make_ref()
    css = Path.join(root, "input.css")
    File.write!(css, "@tailwind utilities;")
    options = [root: root, tailwind: true, tailwind_css: css, tailwind_sources: []]

    on_exit(fn ->
      Volt.Dev.stop(a)
      Volt.Dev.stop(b)
    end)

    assert {:ok, first} =
             Volt.Dev.start([session: a, tailwind_outdir: Path.join(root, "a")] ++ options)

    assert {:ok, second} =
             Volt.Dev.start([session: b, tailwind_outdir: Path.join(root, "b")] ++ options)

    first_worker = GenServer.whereis(:sys.get_state(first).config.tailwind_worker)
    second_worker = GenServer.whereis(:sys.get_state(second).config.tailwind_worker)
    refute first_worker == second_worker
    assert :ok = Volt.Dev.stop(a)
    refute Process.alive?(first_worker)
    assert Process.alive?(second_worker)
    assert :ok = Volt.Dev.stop(b)
    refute Process.alive?(second_worker)
  end

  @tag :tmp_dir
  test "owner exit stops its watcher and clears its state", %{tmp_dir: root} do
    session = make_ref()

    owner =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    assert {:ok, watcher} =
             Volt.Dev.start(session: session, root: root, owner: owner, tailwind: false)

    on_exit(fn ->
      Process.exit(owner, :kill)
      Volt.Dev.stop(session)
    end)

    Volt.Cache.put("/app.js", 1, %Volt.DevServer.CacheEntry{code: "owned"}, session)
    monitor = Process.monitor(watcher)
    send(owner, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^watcher, :normal}
    assert Volt.Cache.get_file("/app.js", session) == nil
    # Supervisor calls are a barrier after processing the linked child's exit.
    children = DynamicSupervisor.which_children(Volt.Dev.WatcherSupervisor)
    refute Enum.any?(children, fn {_, pid, _, _} -> pid == watcher end)
  end

  @tag :tmp_dir
  test "concurrent starts share one watcher and normalized directory options", %{tmp_dir: root} do
    session = make_ref()
    opts = [session: session, root: root, tailwind: false]
    on_exit(fn -> Volt.Dev.stop(session) end)

    results =
      1..8
      |> Task.async_stream(fn _ -> Volt.Dev.start(opts) end, timeout: 15_000)
      |> Enum.to_list()

    pids = Enum.map(results, fn {:ok, {:ok, pid}} -> pid end)
    assert [pid] = Enum.uniq(pids)
    assert {:ok, ^pid} = Volt.Dev.start(opts ++ [watch_dirs: [], reload_dirs: []])
    assert :ok = Volt.Dev.stop(session)
    refute Process.alive?(pid)
    assert {:ok, replacement} = Volt.Dev.start(opts)
    refute replacement == pid
    assert Process.alive?(replacement)
  end

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

    default = Volt.Dev.session_identity(root: root)
    admin = Volt.Dev.session_identity(root: root, id: :admin)

    on_exit(fn ->
      Volt.Dev.stop(default)
      Volt.Dev.stop(admin)
      File.rm_rf!(root)
    end)

    assert {:ok, pid} = Volt.Dev.start(root: root, tailwind: false)
    assert {:ok, ^pid} = Volt.Dev.start(id: :default, root: root, tailwind: false)
    assert {:ok, profile_pid} = Volt.Dev.start(id: :admin, root: root, tailwind: false)
    assert :sys.get_state(pid).tables == Volt.Dev.tables(default)
    refute Volt.Dev.tables(default).owner == Volt.Dev.tables(admin).owner
    assert profile_pid != pid
  end
end
