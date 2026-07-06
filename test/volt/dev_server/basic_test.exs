defmodule Volt.DevServer.BasicTest do
  use Volt.TestSupport.DevServerCase

  describe "HMR endpoints" do
    test "serves HMR client JS" do
      conn = call_dev_server("/@volt/client.js")

      assert conn.status == 200
      assert conn.resp_body =~ "WebSocket"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end
  end

  describe "dev server composition" do
    test "passes through non-asset requests for downstream HTML plugs" do
      opts = Volt.DevServer.init(root: Path.join(@fixture_dir, "src"), prefix: "/assets")

      conn = conn(:get, "/") |> Volt.DevServer.call(opts)

      refute conn.halted

      conn =
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, "<h1>site shell</h1>")

      assert conn.status == 200
      assert conn.resp_body =~ "site shell"
    end

    test "halts asset requests before downstream plugs" do
      opts = Volt.DevServer.init(root: Path.join(@fixture_dir, "src"), prefix: "/assets")

      conn = conn(:get, "/assets/style.css") |> Volt.DevServer.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
    end
  end

  describe "public directory" do
    test "serves public files from the root" do
      public_dir = Path.join(@fixture_dir, "public")
      File.mkdir_p!(public_dir)
      File.write!(Path.join(public_dir, "favicon.svg"), "<svg>public</svg>")

      conn = call_dev_server("/favicon.svg", public_dir: public_dir)

      assert conn.status == 200
      assert conn.resp_body == "<svg>public</svg>"
      assert get_resp_header(conn, "content-type") |> hd() =~ "image/svg"
    end

    test "does not allow public path traversal" do
      File.write!(Path.join(@fixture_dir, "secret.txt"), "secret")
      public_dir = Path.join(@fixture_dir, "public")
      File.mkdir_p!(public_dir)

      conn = call_dev_server("/../secret.txt", public_dir: public_dir)

      assert conn.status == nil
    end
  end

  describe "vendor modules" do
    test "serves shared optimized dependency chunks" do
      for package <- ["editor-a", "editor-b", "singleton-state"] do
        File.mkdir_p!(Path.join(@fixture_dir, "node_modules/#{package}"))

        File.write!(
          Path.join(@fixture_dir, "node_modules/#{package}/package.json"),
          Jason.encode!(%{"name" => package, "main" => "index.js"})
        )
      end

      File.write!(
        Path.join(@fixture_dir, "node_modules/editor-a/index.js"),
        "import { state } from 'singleton-state'; export const a = state;"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/editor-b/index.js"),
        "import { state } from 'singleton-state'; export const b = state;"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/singleton-state/index.js"),
        "export const state = { singleton: true };"
      )

      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { a } from 'editor-a'; import { b } from 'editor-b'; console.log(a, b);"
      )

      app_conn =
        call_dev_server("/assets/app.ts", node_modules: Path.join(@fixture_dir, "node_modules"))

      assert app_conn.status == 200

      assert [vendor_url] = Regex.run(~r(/@vendor/editor-a\.js\?v=[a-f0-9]+), app_conn.resp_body)

      vendor_conn =
        call_dev_server(vendor_url, node_modules: Path.join(@fixture_dir, "node_modules"))

      assert vendor_conn.status == 200

      assert [[_, chunk_path]] =
               Regex.scan(~r{from "\./(chunks/[^"']+\.js)"}, vendor_conn.resp_body)

      chunk_conn =
        call_dev_server("/@vendor/#{chunk_path}",
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      assert chunk_conn.status == 200
      assert chunk_conn.resp_body =~ "singleton"
    end

    test "rejects stale optimized dependency browser hashes" do
      node_modules = Path.join(@fixture_dir, "node_modules/fake-lib")
      File.mkdir_p!(node_modules)

      File.write!(
        Path.join(node_modules, "package.json"),
        Jason.encode!(%{"name" => "fake-lib", "main" => "index.js"})
      )

      File.write!(Path.join(node_modules, "index.js"), "export const value = 'fake'")

      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { value } from 'fake-lib'\nconsole.log(value)"
      )

      app_conn = call_dev_server("/assets/app.ts")
      assert app_conn.status == 200
      assert [vendor_url] = Regex.run(~r(/@vendor/fake-lib\.js\?v=[a-f0-9]+), app_conn.resp_body)

      current_conn = call_dev_server(vendor_url)
      assert current_conn.status == 200

      stale_conn = call_dev_server("/@vendor/fake-lib.js?v=00000000")
      assert stale_conn.status == 504
      assert stale_conn.resp_body =~ "outdated optimized dependency"
    end
  end

  describe "TypeScript files" do
    test "does not allow source path traversal" do
      File.write!(Path.join(@fixture_dir, "secret.ts"), "export const secret = true")

      conn = call_dev_server("/assets/../secret.ts")

      assert conn.status == nil
    end

    test "does not allow sibling-root prefix traversal" do
      sibling = Path.join(@fixture_dir, "src-other")
      File.mkdir_p!(sibling)
      File.write!(Path.join(sibling, "secret.ts"), "export const secret = true")

      conn = call_dev_server("/assets/../src-other/secret.ts")

      assert conn.status == nil
    end

    test "serves compiled TypeScript" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "const x = 42"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "includes inline sourcemap" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.resp_body =~ "sourceMappingURL=data:application/json;base64,"
    end
  end

  describe "embedded plugin modules" do
    test "serves embedded scripts and styles as graph modules" do
      File.write!(Path.join(@fixture_dir, "src/Card.box"), """
      <style>.card { color: red }</style>
      <script>const answer: number = 42; console.log(answer)</script>
      """)

      conn = call_dev_server("/assets/Card.box", plugins: [EmbeddedBoxPlugin])
      assert conn.status == 200

      assert [style_url] =
               Regex.run(~r{/assets/Card\.box\?[^"']*type=style[^"']*}, conn.resp_body)

      assert [script_url] =
               Regex.run(~r{/assets/Card\.box\?[^"']*type=script[^"']*}, conn.resp_body)

      style_conn = call_dev_server(style_url, plugins: [EmbeddedBoxPlugin])
      assert style_conn.status == 200
      assert style_conn.resp_body =~ "color: red"
      assert style_conn.resp_body =~ "__volt_updateStyle"

      script_conn = call_dev_server(script_url, plugins: [EmbeddedBoxPlugin])
      assert script_conn.status == 200
      assert script_conn.resp_body =~ "const answer = 42"
    end
  end
end
