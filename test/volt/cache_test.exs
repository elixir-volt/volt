defmodule Volt.CacheTest do
  use ExUnit.Case, async: false

  setup do
    Volt.Cache.clear()
    :ok
  end

  test "sessions isolate cached content and eviction" do
    path = "/shared/app.css"
    a = %Volt.DevServer.CacheEntry{code: "a"}
    b = %Volt.DevServer.CacheEntry{code: "b"}
    Volt.Cache.put(path, 1, a, :site_a)
    Volt.Cache.put(path, 1, b, :site_b)
    Volt.Cache.put(path <> "?import", 1, a, :site_a)
    assert Volt.Cache.get(path, 1, :site_a) == a
    assert Volt.Cache.get(path, 1, :site_b) == b
    assert Volt.Cache.get(path, 1) == nil
    Volt.Cache.evict_file(path, :site_a)
    assert Volt.Cache.get_file(path, :site_a) == nil
    assert Volt.Cache.get_file(path <> "?import", :site_a) == nil
    assert Volt.Cache.get_file(path, :site_b) == b
    Volt.Cache.clear_session(:site_b)
    assert Volt.Cache.get_file(path, :site_b) == nil
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

  test "get_file returns an entry regardless of mtime" do
    entry = %{
      code: "const x = 1",
      sourcemap: nil,
      css: nil,
      content_type: "application/javascript"
    }

    Volt.Cache.put("/app.ts", 100, entry)
    assert Volt.Cache.get_file("/app.ts") == entry
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

  test "evict_file removes both plain and ?import entries" do
    entry = %{code: "v1", sourcemap: nil, css: nil, content_type: "text/css"}

    import_entry = %{
      code: "import_v1",
      sourcemap: nil,
      css: nil,
      content_type: "application/javascript"
    }

    Volt.Cache.put("/style.css", 100, entry)
    Volt.Cache.put("/style.css?import", 100, import_entry)
    Volt.Cache.evict_file("/style.css")
    assert Volt.Cache.get("/style.css", 100) == nil
    assert Volt.Cache.get("/style.css?import", 100) == nil
  end
end
