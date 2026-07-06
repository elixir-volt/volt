defmodule Volt.CSS.DependenciesTest do
  use ExUnit.Case, async: true

  @root Path.join(System.tmp_dir!(), "volt-css-dependencies-test")

  setup do
    File.rm_rf!(@root)
    File.mkdir_p!(Path.join(@root, "styles/theme"))
    File.mkdir_p!(Path.join(@root, "styles/images"))

    for path <- [
          "styles/tokens.css",
          "styles/extensionless.css",
          "styles/theme/index.css",
          "styles/images/logo.svg",
          "styles/images/font.woff2"
        ] do
      full_path = Path.join(@root, path)
      File.mkdir_p!(Path.dirname(full_path))
      File.write!(full_path, "/* #{path} */")
    end

    on_exit(fn -> File.rm_rf!(@root) end)
    :ok
  end

  test "resolves local CSS imports and URL dependencies relative to the stylesheet" do
    path = Path.join(@root, "styles/app.css")

    source = """
    @import './tokens.css';
    @import './extensionless';
    @import './theme';
    .logo { background: url('./images/logo.svg?v=1') }
    @font-face { src: url('./images/font.woff2') }
    """

    assert Volt.CSS.Dependencies.resolve(source, path) == [
             Path.join(@root, "styles/tokens.css"),
             Path.join(@root, "styles/extensionless.css"),
             Path.join(@root, "styles/theme/index.css"),
             Path.join(@root, "styles/images/logo.svg"),
             Path.join(@root, "styles/images/font.woff2")
           ]
  end

  test "ignores non-local and unresolved dependencies" do
    path = Path.join(@root, "styles/app.css")

    source = """
    @import "https://cdn.example.com/reset.css";
    @import "/assets/global.css";
    .remote { background: url("//cdn.example.com/logo.svg") }
    .data { background: url("data:image/svg+xml,<svg></svg>") }
    .root { background: url("/images/logo.svg") }
    .missing { background: url("./images/missing.svg") }
    .local { background: url("./images/logo.svg") }
    """

    assert Volt.CSS.Dependencies.resolve(source, path) == [
             Path.join(@root, "styles/images/logo.svg")
           ]
  end

  test "returns empty list when CSS cannot be parsed" do
    assert Volt.CSS.Dependencies.resolve(".broken { color: }", Path.join(@root, "app.css")) == []
  end
end
