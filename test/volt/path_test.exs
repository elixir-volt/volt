defmodule Volt.PathTest do
  use ExUnit.Case, async: true

  test "detects paths inside a root" do
    assert Volt.Path.inside?("/site/assets/app.js", "/site/assets")
    assert Volt.Path.inside?("/site/assets", "/site/assets")
    refute Volt.Path.inside?("/site/assets-other/app.js", "/site/assets")
  end

  test "builds relative import specifiers for sibling trees" do
    from = "/site/assets/.astral/islands/gallery.ts"
    to = "/site/assets/islands/Gallery.vue"

    assert Volt.Path.relative_import(from, to) == "../../islands/Gallery.vue"
  end

  test "builds relative import specifiers for same directory files" do
    from = "/site/assets/islands/gallery.ts"
    to = "/site/assets/islands/Gallery.vue"

    assert Volt.Path.relative_import(from, to) == "./Gallery.vue"
  end
end
