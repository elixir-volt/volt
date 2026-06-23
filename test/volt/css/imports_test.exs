defmodule Volt.CSS.ImportsTest do
  use ExUnit.Case, async: true

  @root Path.expand("../fixtures/css_imports", __DIR__)

  test "resolves local CSS imports relative to the importer" do
    path = Path.join(@root, "styles/app.css")
    source = "@import './tokens.css';\n@import '../shared/theme.css' print;"

    assert Volt.CSS.Imports.resolve(source, path) == [
             Path.join(@root, "styles/tokens.css"),
             Path.join(@root, "shared/theme.css")
           ]
  end

  test "ignores non-local imports" do
    path = Path.join(@root, "styles/app.css")

    source = """
    @import "https://cdn.example.com/reset.css";
    @import "//cdn.example.com/theme.css";
    @import "/assets/global.css";
    @import "#fragment";
    @import "./local.css";
    """

    assert Volt.CSS.Imports.resolve(source, path) == [Path.join(@root, "styles/local.css")]
  end

  test "returns empty list when CSS cannot be parsed" do
    assert Volt.CSS.Imports.resolve(".broken { color: }", Path.join(@root, "app.css")) == []
  end
end
