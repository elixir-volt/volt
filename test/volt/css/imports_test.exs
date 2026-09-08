defmodule Volt.CSS.ImportsTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "nested imports retain asset origins without copying files", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "nested/deep"))

    File.write!(
      Path.join(root, "nested/theme.css"),
      "@import './deep/fonts.css'; .logo { background: url('./logo.svg?v=1#mark') }"
    )

    File.write!(
      Path.join(root, "nested/deep/fonts.css"),
      "@font-face { font-family: Test; src: url('./font.woff2') }"
    )

    assert {:ok, css} =
             Volt.CSS.Imports.inline(
               "@import './nested/theme.css';",
               Path.join(root, "app.css"),
               []
             )

    assert css =~ "nested/logo.svg?v=1#mark"
    assert css =~ "nested/deep/font.woff2"
    refute css =~ "@import"
  end

  test "package imports rebase relative to the package stylesheet", %{tmp_dir: root} do
    package = Path.join(root, "node_modules/theme")
    File.mkdir_p!(package)

    File.write!(
      Path.join(package, "package.json"),
      ~s({"name":"theme","exports":{".":"./index.css"}})
    )

    File.write!(Path.join(package, "index.css"), ".theme { background: url('./logo.svg') }")

    assert {:ok, css} =
             Volt.CSS.Imports.inline("@import 'theme';", Path.join(root, "app.css"),
               node_modules: Path.join(root, "node_modules")
             )

    assert css =~ "node_modules/theme/logo.svg"
    refute css =~ "@import"
  end
end
