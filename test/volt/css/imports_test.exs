defmodule Volt.CSS.ImportsTest do
  use ExUnit.Case, async: true

  @root Path.expand("../fixtures/css_imports", __DIR__)

  setup do
    File.rm_rf!(@root)
    File.mkdir_p!(Path.join(@root, "styles/theme"))
    File.mkdir_p!(Path.join(@root, "shared"))

    for path <- [
          "styles/tokens.css",
          "styles/local.css",
          "styles/extensionless.css",
          "styles/theme/index.css",
          "shared/theme.css"
        ] do
      full_path = Path.join(@root, path)
      File.mkdir_p!(Path.dirname(full_path))
      File.write!(full_path, "/* #{path} */")
    end

    on_exit(fn -> File.rm_rf!(@root) end)
    :ok
  end

  test "resolves local CSS imports relative to the importer" do
    path = Path.join(@root, "styles/app.css")
    source = "@import './tokens.css';\n@import '../shared/theme.css' print;"

    assert Volt.CSS.Imports.resolve(source, path) == [
             Path.join(@root, "styles/tokens.css"),
             Path.join(@root, "shared/theme.css")
           ]
  end

  test "resolves extensionless and directory index imports" do
    path = Path.join(@root, "styles/app.css")
    source = "@import './extensionless';\n@import './theme';"

    assert Volt.CSS.Imports.resolve(source, path) == [
             Path.join(@root, "styles/extensionless.css"),
             Path.join(@root, "styles/theme/index.css")
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

  test "ignores unresolved local imports" do
    path = Path.join(@root, "styles/app.css")

    assert Volt.CSS.Imports.resolve("@import './missing';", path) == []
  end

  test "returns empty list when CSS cannot be parsed" do
    assert Volt.CSS.Imports.resolve(".broken { color: }", Path.join(@root, "app.css")) == []
  end
end
