defmodule Volt.Dev.Session.StateTest do
  use ExUnit.Case, async: true

  test "graphs use owned tables and reject stale generation handles" do
    owner = start_supervised!(Volt.Dev.Session.State)
    tables = Volt.Dev.Session.State.tables(owner)
    alias Volt.HMR.{ImportGraph, GlobGraph, StyleGraph, ModuleGraph, Boundary}
    ImportGraph.update("/parent.js", ["./child.js"], tables)
    GlobGraph.update("/parent.js", ["/pages/*.js"], tables)
    StyleGraph.update("/app.css", ["/theme.css"], tables)
    ModuleGraph.update_module("/child.js", "/child.js", "/child.js", [], session: tables)

    ModuleGraph.update_module("/parent.js", "/parent.js", "/parent.js", ["/child.js"],
      session: tables
    )

    read = fn path -> if path == "/parent.js", do: "import.meta.hot.accept()", else: "" end
    assert Boundary.find_boundary("/child.js", read, tables) == {:ok, "/parent.js"}
    assert GlobGraph.dependents("/pages/page.js", tables) == ["/parent.js"]
    assert StyleGraph.dependents("/theme.css", tables) == ["/app.css"]
    assert :ets.info(tables.modules, :owner) == owner
    stop_supervised!(Volt.Dev.Session.State)
    assert_raise ArgumentError, fn -> ImportGraph.update("/parent.js", [], tables) end
    assert_raise ArgumentError, fn -> GlobGraph.update("/parent.js", [], tables) end
    assert_raise ArgumentError, fn -> StyleGraph.update("/app.css", [], tables) end
    assert_raise ArgumentError, fn -> ModuleGraph.get_by_id("/child.js", tables) end
  end

  test "forced owner termination destroys tables without a terminate callback" do
    {:ok, owner} = Volt.Dev.Session.State.start_link([])
    Process.unlink(owner)
    tables = Volt.Dev.Session.State.tables(owner)
    :ets.insert(tables.cache, {:entry, "old"})
    monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}

    for table <- [tables.cache, tables.imports, tables.globs, tables.styles, tables.modules] do
      assert :ets.info(table) == :undefined
    end

    assert_raise ArgumentError, fn -> :ets.insert(tables.cache, {:entry, "stale write"}) end
  end
end
