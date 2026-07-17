defmodule Volt.ChunkGraphTest do
  use ExUnit.Case, async: true

  alias Volt.ChunkGraph

  describe "build/3" do
    test "single entry with no dynamic imports produces one chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/utils.ts", "utils.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: ["/app/utils.ts"], dynamic: []},
        "/app/utils.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert map_size(graph.chunks) == 1
      assert graph.chunks["entry"].type == :entry
      assert "/app/main.ts" in graph.chunks["entry"].modules
      assert "/app/utils.ts" in graph.chunks["entry"].modules
    end

    test "dynamic import creates async chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/utils.ts", "utils.ts", ""},
        {"/app/lazy.ts", "lazy.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: ["/app/utils.ts"], dynamic: ["/app/lazy.ts"]},
        "/app/utils.ts" => %{static: [], dynamic: []},
        "/app/lazy.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert map_size(graph.chunks) == 2
      assert graph.chunks["entry"].type == :entry
      refute "/app/lazy.ts" in graph.chunks["entry"].modules

      async_chunk = Enum.find(Map.values(graph.chunks), &(&1.type == :async))
      assert async_chunk
      assert "/app/lazy.ts" in async_chunk.modules
    end

    test "shared module extracted to common chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/shared.ts", "shared.ts", ""},
        {"/app/lazy.ts", "lazy.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: ["/app/shared.ts"], dynamic: ["/app/lazy.ts"]},
        "/app/shared.ts" => %{static: [], dynamic: []},
        "/app/lazy.ts" => %{static: ["/app/shared.ts"], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      common = graph.chunks["common"]
      assert common
      assert common.type == :common
      assert "/app/shared.ts" in common.modules
    end

    test "extracts modules shared by async chunks even when entry does not import them" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/lazy-a.ts", "lazy-a.ts", ""},
        {"/app/lazy-b.ts", "lazy-b.ts", ""},
        {"/app/shared.ts", "shared.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: [], dynamic: ["/app/lazy-a.ts", "/app/lazy-b.ts"]},
        "/app/lazy-a.ts" => %{static: ["/app/shared.ts"], dynamic: []},
        "/app/lazy-b.ts" => %{static: ["/app/shared.ts"], dynamic: []},
        "/app/shared.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert "/app/shared.ts" in graph.chunks["common"].modules

      refute Enum.any?(Map.values(graph.chunks), fn chunk ->
               chunk.type == :async and "/app/shared.ts" in chunk.modules
             end)
    end

    test "maps dynamic entries shared by multiple chunks to common chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/entry-a.ts", "entry-a.ts", ""},
        {"/app/entry-b.ts", "entry-b.ts", ""},
        {"/app/shared-lazy.ts", "shared-lazy.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: [], dynamic: ["/app/entry-a.ts", "/app/entry-b.ts"]},
        "/app/entry-a.ts" => %{static: ["/app/shared-lazy.ts"], dynamic: []},
        "/app/entry-b.ts" => %{static: ["/app/shared-lazy.ts"], dynamic: []},
        "/app/shared-lazy.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert graph.module_to_chunk["/app/shared-lazy.ts"] == "common"
    end

    test "creates chunks for nested dynamic imports" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/lazy-parent.ts", "lazy-parent.ts", ""},
        {"/app/lazy-child.ts", "lazy-child.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: [], dynamic: ["/app/lazy-parent.ts"]},
        "/app/lazy-parent.ts" => %{static: [], dynamic: ["/app/lazy-child.ts"]},
        "/app/lazy-child.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert graph.module_to_chunk["/app/lazy-parent.ts"] != nil
      assert graph.module_to_chunk["/app/lazy-child.ts"] != nil

      assert graph.module_to_chunk["/app/lazy-parent.ts"] !=
               graph.module_to_chunk["/app/lazy-child.ts"]
    end

    test "records static and dynamic chunk links" do
      main = Path.expand("app/main.ts")
      static_vendor = Path.expand("app/static-vendor.ts")
      lazy = Path.expand("app/lazy.ts")

      modules = [
        {main, "main.ts", ""},
        {static_vendor, "static-vendor.ts", ""},
        {lazy, "lazy.ts", ""}
      ]

      dep_map = %{
        main => %{static: [static_vendor], dynamic: [lazy]},
        static_vendor => %{static: [], dynamic: []},
        lazy => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build(main, modules, dep_map, manual_chunks: %{"vendor" => [static_vendor]})

      assert graph.chunks["entry"].imports == ["vendor"]
      assert graph.chunks["entry"].dynamic_imports == [graph.module_to_chunk[lazy]]
    end

    test "module_to_chunk maps dynamic entry to async chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/lazy.ts", "lazy.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: [], dynamic: ["/app/lazy.ts"]},
        "/app/lazy.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)
      assert graph.module_to_chunk["/app/lazy.ts"] != "entry"
    end

    test "keeps dynamic entry facade even when the entry also imports it statically" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/feature.ts", "feature.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: ["/app/feature.ts"], dynamic: ["/app/feature.ts"]},
        "/app/feature.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map)

      assert graph.module_to_chunk["/app/feature.ts"] != "common"
      assert graph.module_to_chunk["/app/feature.ts"] != "entry"
      assert "/app/feature.ts" in graph.chunks[graph.module_to_chunk["/app/feature.ts"]].modules
    end
  end

  describe "manual chunks" do
    test "extracts matching modules into a named chunk" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/node_modules/vue/index.js", "vue", ""},
        {"/app/node_modules/vue-router/index.js", "vue-router", ""},
        {"/app/utils.ts", "utils.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{
          static: [
            "/app/node_modules/vue/index.js",
            "/app/node_modules/vue-router/index.js",
            "/app/utils.ts"
          ],
          dynamic: []
        },
        "/app/node_modules/vue/index.js" => %{static: [], dynamic: []},
        "/app/node_modules/vue-router/index.js" => %{static: [], dynamic: []},
        "/app/utils.ts" => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build("/app/main.ts", modules, dep_map,
          manual_chunks: %{"vendor" => ["vue", "vue-router"]}
        )

      assert graph.chunks["vendor"].type == :manual
      assert "/app/node_modules/vue/index.js" in graph.chunks["vendor"].modules
      assert "/app/node_modules/vue-router/index.js" in graph.chunks["vendor"].modules

      refute "/app/node_modules/vue/index.js" in graph.chunks["entry"].modules
      assert "/app/utils.ts" in graph.chunks["entry"].modules

      assert "vendor" in graph.chunks["entry"].imports
    end

    test "path patterns match by directory prefix" do
      main = Path.expand("app/main.ts")
      button = Path.expand("app/src/components/Button.ts")
      modal = Path.expand("app/src/components/Modal.ts")
      utils = Path.expand("app/src/utils.ts")

      modules = [
        {main, "main.ts", ""},
        {button, "Button.ts", ""},
        {modal, "Modal.ts", ""},
        {utils, "utils.ts", ""}
      ]

      dep_map = %{
        main => %{static: [button, modal, utils], dynamic: []},
        button => %{static: [], dynamic: []},
        modal => %{static: [], dynamic: []},
        utils => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build(main, modules, dep_map, manual_chunks: %{"ui" => [Path.dirname(button)]})

      assert graph.chunks["ui"].type == :manual
      assert button in graph.chunks["ui"].modules
      assert modal in graph.chunks["ui"].modules

      refute utils in graph.chunks["ui"].modules
    end

    test "manual chunks coexist with dynamic imports" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/node_modules/vue/index.js", "vue", ""},
        {"/app/lazy.ts", "lazy.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{
          static: ["/app/node_modules/vue/index.js"],
          dynamic: ["/app/lazy.ts"]
        },
        "/app/node_modules/vue/index.js" => %{static: [], dynamic: []},
        "/app/lazy.ts" => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build("/app/main.ts", modules, dep_map, manual_chunks: %{"vendor" => ["vue"]})

      assert graph.chunks["vendor"].type == :manual
      assert graph.chunks["entry"].type == :entry

      async = Enum.find(Map.values(graph.chunks), &(&1.type == :async))
      assert async
      assert "/app/lazy.ts" in async.modules
    end

    test "module_to_chunk reflects manual assignments" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/node_modules/lodash/index.js", "lodash", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{
          static: ["/app/node_modules/lodash/index.js"],
          dynamic: []
        },
        "/app/node_modules/lodash/index.js" => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build("/app/main.ts", modules, dep_map,
          manual_chunks: %{"vendor" => ["lodash"]}
        )

      assert graph.module_to_chunk["/app/node_modules/lodash/index.js"] == "vendor"
    end

    test "empty manual chunks config has no effect" do
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/utils.ts", "utils.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{static: ["/app/utils.ts"], dynamic: []},
        "/app/utils.ts" => %{static: [], dynamic: []}
      }

      graph = ChunkGraph.build("/app/main.ts", modules, dep_map, manual_chunks: %{})
      assert map_size(graph.chunks) == 1
    end
  end
end
