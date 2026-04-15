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
      modules = [
        {"/app/main.ts", "main.ts", ""},
        {"/app/src/components/Button.ts", "Button.ts", ""},
        {"/app/src/components/Modal.ts", "Modal.ts", ""},
        {"/app/src/utils.ts", "utils.ts", ""}
      ]

      dep_map = %{
        "/app/main.ts" => %{
          static: [
            "/app/src/components/Button.ts",
            "/app/src/components/Modal.ts",
            "/app/src/utils.ts"
          ],
          dynamic: []
        },
        "/app/src/components/Button.ts" => %{static: [], dynamic: []},
        "/app/src/components/Modal.ts" => %{static: [], dynamic: []},
        "/app/src/utils.ts" => %{static: [], dynamic: []}
      }

      graph =
        ChunkGraph.build("/app/main.ts", modules, dep_map,
          manual_chunks: %{"ui" => ["/app/src/components"]}
        )

      assert graph.chunks["ui"].type == :manual
      assert "/app/src/components/Button.ts" in graph.chunks["ui"].modules
      assert "/app/src/components/Modal.ts" in graph.chunks["ui"].modules

      refute "/app/src/utils.ts" in graph.chunks["ui"].modules
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
        ChunkGraph.build("/app/main.ts", modules, dep_map,
          manual_chunks: %{"vendor" => ["vue"]}
        )

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
