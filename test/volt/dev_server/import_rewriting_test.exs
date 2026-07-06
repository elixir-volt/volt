defmodule Volt.DevServer.ImportRewritingTest do
  use Volt.TestSupport.DevServerCase

  describe "import rewriting" do
    test "rewrites relative imports to absolute paths" do
      File.write!(Path.join(@fixture_dir, "src/utils.ts"), "export const y = 1")

      File.write!(Path.join(@fixture_dir, "src/entry.ts"), """
      import { y } from './utils'
      console.log(y)
      """)

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/utils.ts"
      refute conn.resp_body =~ "'./utils'"
    end

    test "rewrites package imports from nearest package imports map" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/internal"))

      File.write!(
        Path.join(@fixture_dir, "src/package.json"),
        Jason.encode!(%{
          "name" => "fixture-app",
          "imports" => %{"#internal/value" => "./internal/value.js"}
        })
      )

      File.write!(Path.join(@fixture_dir, "src/internal/value.js"), "export const value = 1")

      File.write!(
        Path.join(@fixture_dir, "src/entry.ts"),
        "import { value } from '#internal/value'\nconsole.log(value)"
      )

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/internal/value.js"
      refute conn.resp_body =~ "'#internal/value'"
    end

    test "rewrites CSS imports to import-mode URLs" do
      File.write!(Path.join(@fixture_dir, "src/entry.ts"), "import './style.css'")

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/style.css?import"
      refute conn.resp_body =~ "'./style.css'"
    end

    test "rewrites virtual module imports to virtual dev URLs" do
      File.write!(
        Path.join(@fixture_dir, "src/entry.ts"),
        "import routes from 'virtual:routes'; console.log(routes)"
      )

      conn = call_dev_server("/assets/entry.ts", plugins: [VirtualPlugin])

      assert conn.status == 200
      assert conn.resp_body =~ "/@volt/virtual/virtual:routes"
      refute conn.resp_body =~ "'virtual:routes'"
    end

    test "serves plugin-loaded virtual modules" do
      conn = call_dev_server("/@volt/virtual/virtual:routes", plugins: [VirtualPlugin])

      assert conn.status == 200
      assert conn.resp_body =~ "path"
      assert conn.resp_body =~ "import.meta.hot"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "extensionless virtual modules without content type default to JavaScript" do
      conn = call_dev_server("/@volt/virtual/virtual:plain", plugins: [VirtualPlugin])

      assert conn.status == 200
      assert conn.resp_body =~ "123"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "virtual modules can import other virtual modules" do
      conn = call_dev_server("/@volt/virtual/virtual:client", plugins: [VirtualPlugin])

      assert conn.status == 200
      assert conn.resp_body =~ "/@volt/virtual/virtual:routes"
      refute conn.resp_body =~ "'virtual:routes'"
    end

    test "rewrites asset imports to import-mode URLs" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/entry.ts"),
        "import logo from './logo.svg'\nconsole.log(logo)"
      )

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/logo.svg?import"
      refute conn.resp_body =~ "'./logo.svg'"
    end

    test "preserves asset import query modes while rewriting" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/entry.ts"),
        "import logo from './logo.svg?raw'\nconsole.log(logo)"
      )

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/logo.svg?raw"
      refute conn.resp_body =~ "/assets/logo.svg?import"
    end

    test "rewrites nested asset imports to import-mode URLs" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/entry.ts"),
        "import logo from './images/logo.svg'\nconsole.log(logo)"
      )

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/images/logo.svg?import"
      refute conn.resp_body =~ "'./images/logo.svg'"
    end

    test "rewrites bare imports to vendor URLs" do
      File.write!(Path.join(@fixture_dir, "src/vue_app.ts"), """
      import { ref } from 'vue'
      ref(0)
      """)

      conn = call_dev_server("/assets/vue_app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/@vendor/vue.js"
      refute conn.resp_body =~ "'vue'"
    end
  end

  describe "HMR preamble" do
    test "injects import.meta.hot into JS modules" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.resp_body =~ "import.meta.hot"
      assert conn.resp_body =~ "createHotContext"
    end

    test "does not inject HMR preamble into CSS" do
      conn = call_dev_server("/assets/style.css")
      refute conn.resp_body =~ "import.meta.hot"
    end
  end
end
