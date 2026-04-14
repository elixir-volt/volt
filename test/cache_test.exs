defmodule Volt.CacheTest do
  use ExUnit.Case, async: false

  setup do
    Volt.Cache.clear()
    :ok
  end

  test "get returns nil on miss" do
    assert Volt.Cache.get("/app.ts", 12345) == nil
  end

  test "put and get round-trip" do
    entry = %{
      code: "const x = 1",
      sourcemap: nil,
      css: nil,
      content_type: "application/javascript"
    }

    Volt.Cache.put("/app.ts", 100, entry)
    assert Volt.Cache.get("/app.ts", 100) == entry
  end

  test "different mtime is a miss" do
    entry = %{
      code: "const x = 1",
      sourcemap: nil,
      css: nil,
      content_type: "application/javascript"
    }

    Volt.Cache.put("/app.ts", 100, entry)
    assert Volt.Cache.get("/app.ts", 101) == nil
  end

  test "evict removes all entries for a path" do
    entry = %{code: "v1", sourcemap: nil, css: nil, content_type: "application/javascript"}
    Volt.Cache.put("/app.ts", 100, entry)
    Volt.Cache.put("/app.ts", 101, %{entry | code: "v2"})
    Volt.Cache.evict("/app.ts")
    assert Volt.Cache.get("/app.ts", 100) == nil
    assert Volt.Cache.get("/app.ts", 101) == nil
  end
end
