defmodule Volt.Dev.Session.SupervisorTest do
  use ExUnit.Case, async: true

  defmodule Witness do
    use GenServer
    def start_link(parent), do: GenServer.start_link(__MODULE__, parent)

    def init(parent) do
      send(parent, {:dependent_started, self()})
      {:ok, parent}
    end
  end

  @tag :tmp_dir
  test "Tailwind compilation stays inside the subtree", %{tmp_dir: root} do
    identity = make_ref()
    css = Path.join(root, "app.css")
    File.write!(css, "@tailwind utilities;")
    count = Registry.count(Volt.Tailwind.Registry)

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: identity,
         watcher: [
           root: root,
           name: nil,
           tailwind: true,
           tailwind_css: css,
           tailwind_sources: [],
           tailwind_outdir: Path.join(root, "output")
         ]}
      )

    children = Supervisor.which_children(supervisor)
    {_, worker, _, _} = Enum.find(children, fn {id, _, _, _} -> id == Volt.Tailwind.Worker end)
    {_, runtime, _, _} = Enum.find(children, fn {id, _, _, _} -> id == Volt.Tailwind.Runtime end)
    assert :sys.get_state(worker).last_css
    refute File.exists?(Path.join(root, "output"))
    tables = Volt.Dev.Session.Supervisor.tables(supervisor)
    assert tables.stylesheet_worker == worker
    assert :sys.get_state(runtime).pid
    assert Registry.count(Volt.Tailwind.Registry) == count
    stop_supervised!(Volt.Dev.Session.Supervisor)
    refute Process.alive?(worker)
    refute Process.alive?(runtime)
  end

  test "session subtree owns its lazy Tailwind runtime", %{test: test} do
    identity = {test, make_ref()}
    root = System.tmp_dir!()

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: identity, watcher: [root: root, name: nil, tailwind: false]}
      )

    {_, runtime, _, _} =
      Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
        id == Volt.Tailwind.Runtime
      end)

    assert :sys.get_state(runtime) == nil
    assert {:ok, _} = Volt.Tailwind.Runtime.call("@tailwind utilities;", ["flex"], root, runtime)
    compiler = :sys.get_state(runtime).pid
    monitor = Process.monitor(compiler)
    stop_supervised!(Volt.Dev.Session.Supervisor)
    assert_receive {:DOWN, ^monitor, :process, ^compiler, _}
    refute Process.alive?(runtime)
  end

  test "real watcher restarts with replacement table handles", %{test: test} do
    root = Path.join(System.tmp_dir!(), "volt-owned-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: {test, make_ref()}, watcher: [root: root, name: nil, tailwind: false]}
      )

    children = Supervisor.which_children(supervisor)
    {_, owner, _, _} = Enum.find(children, fn {id, _, _, _} -> id == Volt.Dev.Session.State end)

    {_, watcher, _, _} =
      Enum.find(children, fn {id, _, _, _} -> id == Volt.Dev.Session.Watcher end)

    tables = Volt.Dev.Session.State.tables(owner)
    assert :sys.get_state(watcher).tables == tables
    Volt.Cache.put("/app.js", 1, %Volt.DevServer.CacheEntry{code: "owned"}, tables)
    assert Volt.Cache.get_file("/app.js", tables).code == "owned"
    monitor = Process.monitor(watcher)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^watcher, :shutdown}
    children = Supervisor.which_children(supervisor)

    {_, replacement, _, _} =
      Enum.find(children, fn {id, _, _, _} -> id == Volt.Dev.Session.Watcher end)

    refute :sys.get_state(replacement).tables.generation == tables.generation

    assert_raise ArgumentError, fn ->
      Volt.Cache.put("/app.js", 1, %Volt.DevServer.CacheEntry{}, tables)
    end
  end

  test "state owner failure restarts dependent children with a new generation" do
    supervisor = start_supervised!({Volt.Dev.Session.Supervisor, children: [{Witness, self()}]})
    assert_receive {:dependent_started, first}

    {_, owner, _, _} =
      Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
        id == Volt.Dev.Session.State
      end)

    old = Volt.Dev.Session.State.tables(owner)
    monitor = Process.monitor(first)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^first, :shutdown}
    assert_receive {:dependent_started, second}
    refute first == second

    {_, replacement, _, _} =
      Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
        id == Volt.Dev.Session.State
      end)

    new = Volt.Dev.Session.State.tables(replacement)
    refute old.generation == new.generation
    assert :ets.info(old.cache) == :undefined
    assert :ets.info(new.cache, :owner) == replacement
  end
end
