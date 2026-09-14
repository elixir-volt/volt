defmodule Volt.HMR.GlobGraphTest do
  use ExUnit.Case, async: false

  alias Volt.HMR.GlobGraph

  setup do
    GlobGraph.clear()
    :ok
  end

  test "isolates glob ownership, removal, and cleanup by session" do
    importer = "/src/routes.ts"
    GlobGraph.update(importer, ["/src/a/*.ts"], :a)
    GlobGraph.update(importer, ["/src/b/*.ts"], :b)
    assert GlobGraph.dependents("/src/a/page.ts", :a) == [importer]
    assert GlobGraph.dependents("/src/a/page.ts", :b) == []
    assert GlobGraph.dependents("/src/a/page.ts") == []
    GlobGraph.remove(importer, :a)
    assert GlobGraph.dependents("/src/b/page.ts", :b) == [importer]
    GlobGraph.clear_session(:b)
    assert GlobGraph.dependents("/src/b/page.ts", :b) == []
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
