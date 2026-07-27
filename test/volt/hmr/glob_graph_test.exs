defmodule Volt.HMR.GlobGraphTest do
  use ExUnit.Case, async: false

  alias Volt.HMR.GlobGraph

  setup do
    GlobGraph.clear()
    :ok
  end

  test "finds importers whose glob patterns match a path" do
    GlobGraph.update("/src/routes.ts", ["/src/pages/*.ts"])

    assert GlobGraph.dependents("/src/pages/home.ts") == ["/src/routes.ts"]
    assert GlobGraph.dependents("/src/components/home.ts") == []
  end

  test "matches Windows drive letters case-insensitively" do
    GlobGraph.update("C:/src/routes.ts", ["c:/src/pages/*.ts"])

    assert GlobGraph.dependents("C:/src/pages/home.ts") == ["C:/src/routes.ts"]
  end

  test "honors negated patterns" do
    GlobGraph.update("/src/routes.ts", ["/src/pages/*.ts", "!/src/pages/*.test.ts"])

    assert GlobGraph.dependents("/src/pages/home.ts") == ["/src/routes.ts"]
    assert GlobGraph.dependents("/src/pages/home.test.ts") == []
  end

  test "extracts patterns from import.meta.glob source" do
    source = "const pages = import.meta.glob('./pages/*.ts')"
    importer = Path.expand("src/routes.ts")
    page = Path.expand("src/pages/home.ts")

    GlobGraph.update_from_source(importer, source)

    assert GlobGraph.dependents(page) == [importer]
  end
end
