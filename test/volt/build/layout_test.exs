defmodule Volt.Build.LayoutTest do
  use ExUnit.Case, async: true

  alias Volt.Build.Layout

  test "asset directory prefixes both layout presets" do
    assert Layout.new(:flat, "assets") == %Layout{scripts: "assets", styles: "assets"}
    assert Layout.new(:split, "assets") == %Layout{scripts: "assets/js", styles: "assets/css"}
    assert Layout.new(:flat) == %Layout{scripts: "", styles: ""}
  end

  test "asset directory cannot escape the publication root" do
    for path <- ["/assets", "../assets", "a/../assets", "C:\\assets"] do
      assert_raise ArgumentError, fn -> Layout.new(:flat, path) end
    end
  end
end
