defmodule Volt.DepGraphTest do
  use ExUnit.Case, async: false

  setup do
    Volt.DepGraph.clear()
    :ok
  end

  test "tracks imports for a file" do
    Volt.DepGraph.update("/src/App.vue", ["vue", "./utils"])
    assert Volt.DepGraph.imports_of("/src/App.vue") == ["vue", "./utils"]
  end

  test "finds dependents of a specifier" do
    Volt.DepGraph.update("/src/App.vue", ["./utils", "vue"])
    Volt.DepGraph.update("/src/Page.vue", ["./utils"])
    Volt.DepGraph.update("/src/main.ts", ["vue"])

    dependents = Volt.DepGraph.dependents("./utils")
    assert "/src/App.vue" in dependents
    assert "/src/Page.vue" in dependents
    refute "/src/main.ts" in dependents
  end

  test "update replaces previous imports" do
    Volt.DepGraph.update("/src/App.vue", ["vue", "./old"])
    Volt.DepGraph.update("/src/App.vue", ["vue", "./new"])
    assert Volt.DepGraph.imports_of("/src/App.vue") == ["vue", "./new"]
  end

  test "remove deletes a file from the graph" do
    Volt.DepGraph.update("/src/App.vue", ["vue"])
    Volt.DepGraph.remove("/src/App.vue")
    assert Volt.DepGraph.imports_of("/src/App.vue") == []
  end
end
