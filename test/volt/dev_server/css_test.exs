defmodule Volt.DevServer.CSSTest do
  use Volt.TestSupport.DevServerCase

  describe "CSS files" do
    test "serves CSS with correct content type" do
      conn = call_dev_server("/assets/style.css")
      assert conn.status == 200
      assert conn.resp_body =~ "color"
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
    end

    test "serves bare package CSS imports" do
      css_pkg_dir = Path.join(@fixture_dir, "vendor/csslib")
      File.mkdir_p!(css_pkg_dir)
      File.write!(Path.join(css_pkg_dir, "theme.css"), ".from-node-module { color: red }")

      File.write!(Path.join(css_pkg_dir, "package.json"), ~s({
        "name": "csslib",
        "exports": { "./theme.css": "./theme.css" }
      }))

      File.write!(Path.join(@fixture_dir, "src/style.css"), ~s(@import "csslib/theme.css";))

      conn =
        call_dev_server("/assets/style.css", resolve_dirs: [Path.join(@fixture_dir, "vendor")])

      assert conn.status == 200
      assert conn.resp_body =~ ".from-node-module"
    end

    test "serves CSS imports as JavaScript modules" do
      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "__volt_updateStyle"
      assert conn.resp_body =~ "color"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves CSS import requests with cache-busting params as JavaScript modules" do
      conn = call_dev_server("/assets/style.css?import&t=123")
      assert conn.status == 200
      assert conn.resp_body =~ "__volt_updateStyle"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "rewrites CSS import module asset URLs to dev-server URLs" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/style.css"),
        ".logo { background: url('./images/logo.svg?v=1') }"
      )

      conn = call_dev_server("/assets/style.css?import")

      assert conn.status == 200
      assert conn.resp_body =~ "/assets/images/logo.svg?v=1"
      refute conn.resp_body =~ "./images/logo.svg"
    end

    test "rewrites direct CSS asset URLs to dev-server URLs" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/style.css"),
        ".logo { background: url('./images/logo.svg') }"
      )

      conn = call_dev_server("/assets/style.css")

      assert conn.status == 200
      assert conn.resp_body =~ "/assets/images/logo.svg"
      refute conn.resp_body =~ "./images/logo.svg"
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
    end

    test "serves raw query for non-asset extensions as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/note.md"), "# Hello\n\nfrom markdown")

      conn = call_dev_server("/assets/note.md?raw")

      assert conn.status == 200
      assert conn.resp_body == ~s(export default "# Hello\\n\\nfrom markdown";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves raw CSS and CSS import modules from separate cache entries" do
      import_conn = call_dev_server("/assets/style.css?import")
      raw_conn = call_dev_server("/assets/style.css")

      assert import_conn.resp_body =~ "__volt_updateStyle"
      assert get_resp_header(import_conn, "content-type") |> hd() =~ "javascript"

      assert raw_conn.resp_body =~ "color: red"
      refute raw_conn.resp_body =~ "__volt_updateStyle"
      assert get_resp_header(raw_conn, "content-type") |> hd() =~ "text/css"
    end

    test "serves CSS modules imported from JavaScript with styles and exports" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/button.module.css"),
        ".btn { color: red; background: url('./logo.svg') }"
      )

      conn = call_dev_server("/assets/button.module.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "__volt_updateStyle"
      assert conn.resp_body =~ "color: red"
      assert conn.resp_body =~ "/assets/logo.svg"
      assert conn.resp_body =~ "export default"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "tracks CSS module asset dependencies" do
      logo_path = Path.join(@fixture_dir, "src/logo.svg")
      module_path = Path.join(@fixture_dir, "src/button.module.css")

      File.write!(logo_path, "<svg></svg>")
      File.write!(module_path, ".btn { background: url('./logo.svg') }")

      conn = call_dev_server("/assets/button.module.css?import")

      assert conn.status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [module_path]
    end

    test "removes stale CSS module asset dependencies" do
      logo_path = Path.join(@fixture_dir, "src/logo.svg")
      module_path = Path.join(@fixture_dir, "src/button.module.css")

      File.write!(logo_path, "<svg></svg>")
      File.write!(module_path, ".btn { background: url('./logo.svg') }")
      File.touch!(module_path, {{2026, 1, 1}, {0, 0, 0}})

      assert call_dev_server("/assets/button.module.css?import").status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [module_path]

      File.write!(module_path, ".btn { color: red }")
      File.touch!(module_path, {{2026, 1, 1}, {0, 0, 1}})

      assert call_dev_server("/assets/button.module.css?import").status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == []
      assert Volt.HMR.StyleGraph.dependencies_of(module_path) == []
    end

    test "serves CSS modules as JavaScript even without import query" do
      File.write!(Path.join(@fixture_dir, "src/button.module.css"), ".btn { color: red }")

      conn = call_dev_server("/assets/button.module.css")
      assert conn.status == 200
      assert conn.resp_body =~ "__volt_updateStyle"
      assert conn.resp_body =~ "export default"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end
  end
end
