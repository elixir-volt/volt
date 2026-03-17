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
end
