defmodule Volt.DevServerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  @fixture_dir Path.expand("fixtures", __DIR__)

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "src"))
    File.write!(Path.join(@fixture_dir, "src/app.ts"), "const x: number = 42")
    File.write!(Path.join(@fixture_dir, "src/style.css"), ".foo { color: red }")

    File.write!(Path.join(@fixture_dir, "src/App.vue"), """
    <template><div>{{ msg }}</div></template>
    <script setup>const msg = 'hi'</script>
    """)

    Volt.Cache.clear()
    Volt.HMR.CSSImportGraph.clear()
    Volt.HMR.ModuleGraph.clear()

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  defp call_dev_server(path, opts \\ []) do
    init_opts =
      Keyword.merge(
        [root: Path.join(@fixture_dir, "src"), prefix: "/assets"],
        opts
      )

    opts = Volt.DevServer.init(init_opts)
    conn(:get, path) |> Volt.DevServer.call(opts)
  end

  describe "HMR endpoints" do
    test "serves HMR client JS" do
      conn = call_dev_server("/@volt/client.js")

      assert conn.status == 200
      assert conn.resp_body =~ "WebSocket"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
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

  describe "Vue SFCs" do
    test "serves compiled Vue SFC" do
      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200
      assert conn.resp_body =~ "msg"
    end

    test "serves Vue SFCs with JavaScript postprocess transforms applied" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/pages"))
      File.write!(Path.join(@fixture_dir, "src/pages/home.ts"), "export const page = 'home'")

      File.write!(Path.join(@fixture_dir, "src/WithMeta.vue"), """
      <script setup lang="ts">
      const pages = import.meta.glob('./pages/*.ts', { eager: true })
      const mode = import.meta.env.MODE
      </script>
      <template><p>{{ mode }}</p></template>
      """)

      conn = call_dev_server("/assets/WithMeta.vue")
      assert conn.status == 200
      refute conn.resp_body =~ "import.meta.glob"
      assert conn.resp_body =~ "/assets/pages/home.ts"
      assert conn.resp_body =~ ~s("MODE": "development")
      assert conn.resp_body =~ "import.meta.env.MODE"
    end
  end

  describe "CSS files" do
    test "serves CSS with correct content type" do
      conn = call_dev_server("/assets/style.css")
      assert conn.status == 200
      assert conn.resp_body =~ "color"
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
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

    test "serves CSS modules as JavaScript even without import query" do
      File.write!(Path.join(@fixture_dir, "src/button.module.css"), ".btn { color: red }")

      conn = call_dev_server("/assets/button.module.css")
      assert conn.status == 200
      assert conn.resp_body =~ "__volt_updateStyle"
      assert conn.resp_body =~ "export default"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end
  end

  describe "caching" do
    test "records served modules in HMR module graph" do
      File.write!(Path.join(@fixture_dir, "src/dep.ts"), "export const dep = 1")

      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { dep } from './dep'\nconsole.log(dep)"
      )

      call_dev_server("/assets/app.ts")
      call_dev_server("/assets/dep.ts")

      node = Volt.HMR.ModuleGraph.get_by_url("/assets/app.ts")
      dep = Volt.HMR.ModuleGraph.get_by_url("/assets/dep.ts")

      assert node.file == Path.join(@fixture_dir, "src/app.ts")
      assert node.type == :js
      assert MapSet.member?(node.imports, "/assets/dep.ts")
      assert MapSet.member?(dep.importers, "/assets/app.ts")
    end

    test "records CSS import query variants separately in HMR module graph" do
      call_dev_server("/assets/style.css")
      call_dev_server("/assets/style.css?import")

      nodes = Volt.HMR.ModuleGraph.get_by_file(Path.join(@fixture_dir, "src/style.css"))

      assert Enum.map(nodes, & &1.url) |> Enum.sort() == [
               "/assets/style.css",
               "/assets/style.css?import"
             ]
    end

    test "serves from cache on second request" do
      call_dev_server("/assets/app.ts")
      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "const x = 42"
    end

    test "watcher invalidation does not replace dev-server cache" do
      source_dir = Path.join(@fixture_dir, "src")
      app_path = Path.join(source_dir, "app.ts")

      File.write!(app_path, """
      import "phoenix_html"
      console.log(import.meta.env.DEV, "before")
      """)

      File.touch!(app_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/app.ts")

      assert conn.status == 200
      assert conn.resp_body =~ "before"
      assert conn.resp_body =~ "createHotContext"
      assert conn.resp_body =~ "/@vendor/phoenix_html.js"
      refute conn.resp_body =~ ~s(import "phoenix_html")

      File.write!(app_path, """
      import "phoenix_html"
      console.log(import.meta.env.DEV, "after")
      """)

      File.touch!(app_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_dev_server_watcher_cache})

      send(watcher, {:rebuild, app_path})
      _ = :sys.get_state(watcher)

      conn = call_dev_server("/assets/app.ts")

      assert conn.status == 200
      assert conn.resp_body =~ "after"
      assert conn.resp_body =~ "createHotContext"
      assert conn.resp_body =~ "/@vendor/phoenix_html.js"
      refute conn.resp_body =~ ~s(import "phoenix_html")
    end

    test "watcher compares changed files against previous cached hashes" do
      source_dir = Path.join(@fixture_dir, "src")
      vue_path = Path.join(source_dir, "App.vue")
      Registry.register(Volt.HMR.Registry, :clients, nil)

      File.write!(vue_path, """
      <template><div>{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.foo { color: red }</style>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200

      File.write!(vue_path, """
      <template><div>{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.foo { color: green }</style>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_hmr_cached_hashes})

      send(watcher, {:rebuild, vue_path})

      assert_receive {:volt_hmr, :update, %{path: "App.vue", changes: [:style]}}, 1000
    end

    test "watcher invalidation evicts CSS import cache" do
      source_dir = Path.join(@fixture_dir, "src")
      css_path = Path.join(source_dir, "style.css")

      File.write!(css_path, ".foo { color: red }")
      File.touch!(css_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "red"
      assert conn.resp_body =~ "__volt_updateStyle"

      File.write!(css_path, ".foo { color: green }")
      File.touch!(css_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_css_import_cache})

      send(watcher, {:rebuild, css_path})
      _ = :sys.get_state(watcher)

      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "green"
      refute conn.resp_body =~ "red"
    end

    test "watcher invalidates CSS importers when imported CSS changes" do
      source_dir = Path.join(@fixture_dir, "src")
      app_css_path = Path.join(source_dir, "style.css")
      tokens_css_path = Path.join(source_dir, "tokens.css")
      Registry.register(Volt.HMR.Registry, :clients, nil)

      File.write!(tokens_css_path, ":root { --brand: red }")
      File.write!(app_css_path, "@import './tokens.css';\n.foo { color: var(--brand) }")
      File.touch!(app_css_path, {{2026, 1, 1}, {0, 0, 0}})
      File.touch!(tokens_css_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "--brand: red"

      File.write!(tokens_css_path, ":root { --brand: green }")
      File.touch!(tokens_css_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_css_import_dependents})

      send(watcher, {:file_event, self(), {tokens_css_path, [:modified]}})
      _ = :sys.get_state(watcher)

      assert_receive {:volt_hmr, :update, %{path: "style.css", changes: [:style]}}, 1000

      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "--brand: green"
      refute conn.resp_body =~ "--brand: red"
    end

    test "watcher invalidation evicts cache even for never-served files" do
      source_dir = Path.join(@fixture_dir, "src")
      app_path = Path.join(source_dir, "app.ts")

      File.write!(app_path, "export const x = 1")
      File.touch!(app_path, {{2026, 1, 1}, {0, 0, 0}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_never_served})

      send(watcher, {:rebuild, app_path})
      _ = :sys.get_state(watcher)

      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "createHotContext"
    end

    test "compilation error does not serve stale cache" do
      source_dir = Path.join(@fixture_dir, "src")
      app_path = Path.join(source_dir, "app.ts")

      File.write!(app_path, "export const x = 1")
      File.touch!(app_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "const x = 1"

      File.write!(app_path, "const = ;")
      File.touch!(app_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_compile_error})

      send(watcher, {:rebuild, app_path})
      _ = :sys.get_state(watcher)

      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 500
      refute conn.resp_body =~ "const x = 1"
    end
  end

  describe "non-matching paths" do
    test "passes through non-matching prefix" do
      conn = call_dev_server("/other/app.ts")
      refute conn.halted
    end

    test "serves static assets with correct MIME type" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "image/png"
    end

    test "serves asset imports as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?import")
      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/png;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves raw asset query as a JavaScript string module" do
      File.write!(Path.join(@fixture_dir, "src/data.txt"), "hello\nworld")
      conn = call_dev_server("/assets/data.txt?raw")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "hello\\nworld";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves URL asset query as a JavaScript URL module" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?url")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves asset script fetches as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/icon.svg"), "<svg></svg>")

      opts = Volt.DevServer.init(root: Path.join(@fixture_dir, "src"), prefix: "/assets")

      conn =
        conn(:get, "/assets/icon.svg")
        |> put_req_header("sec-fetch-dest", "script")
        |> Volt.DevServer.call(opts)

      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/svg+xml;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves large asset imports with their dev URL" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/image.png"), String.duplicate("x", 4097))
      conn = call_dev_server("/assets/images/image.png?import")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/images/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "passes through unknown extensions" do
      File.write!(Path.join(@fixture_dir, "src/data.xyz"), "binary")
      conn = call_dev_server("/assets/data.xyz")
      refute conn.halted
    end

    test "passes through missing files" do
      conn = call_dev_server("/assets/missing.ts")
      refute conn.halted
    end
  end

  describe "error handling" do
    test "returns 500 with error overlay for invalid source" do
      File.write!(Path.join(@fixture_dir, "src/bad.ts"), "const = ;")
      conn = call_dev_server("/assets/bad.ts")
      assert conn.status == 500
      assert conn.resp_body =~ "[Volt] Compilation error"
    end
  end

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

    test "rewrites CSS imports to import-mode URLs" do
      File.write!(Path.join(@fixture_dir, "src/entry.ts"), "import './style.css'")

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/style.css?import"
      refute conn.resp_body =~ "'./style.css'"
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
