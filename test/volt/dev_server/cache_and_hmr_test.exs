defmodule Volt.DevServer.CacheAndHMRTest do
  use Volt.TestSupport.DevServerCase

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

    test "watcher removes stale Vue style asset dependencies" do
      source_dir = Path.join(@fixture_dir, "src")
      vue_path = Path.join(source_dir, "App.vue")
      logo_path = Path.join(source_dir, "logo.svg")
      Registry.register(Volt.HMR.Registry, :clients, nil)

      File.write!(logo_path, "<svg>red</svg>")

      File.write!(vue_path, """
      <template><div class="logo">{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 0}})
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 0}})

      assert call_dev_server("/assets/App.vue").status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [vue_path]

      File.write!(vue_path, """
      <template><div>{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_vue_style_stale_asset})

      send(watcher, {:rebuild, vue_path})
      _ = :sys.get_state(watcher)
      assert Volt.HMR.StyleGraph.dependents(logo_path) == []
      flush_hmr_messages()

      File.write!(logo_path, "<svg>green</svg>")
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 1}})
      send(watcher, {:file_event, self(), {logo_path, [:modified]}})
      _ = :sys.get_state(watcher)

      assert_receive {:volt_hmr, :update, %{path: "logo.svg", changes: [:full]}}, 1000
      refute_receive {:volt_hmr, :update, %{path: "App.vue", changes: [:style]}}, 100
    end

    test "watcher invalidates Vue style owners when referenced assets change" do
      source_dir = Path.join(@fixture_dir, "src")
      vue_path = Path.join(source_dir, "App.vue")
      logo_path = Path.join(source_dir, "logo.svg")
      Registry.register(Volt.HMR.Registry, :clients, nil)

      File.write!(logo_path, "<svg>red</svg>")

      File.write!(vue_path, """
      <template><div class="logo">{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 0}})
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200

      File.write!(logo_path, "<svg>green</svg>")
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!(
          {Volt.Watcher, root: source_dir, name: :test_vue_style_asset_dependents}
        )

      send(watcher, {:file_event, self(), {logo_path, [:modified]}})
      _ = :sys.get_state(watcher)

      assert_receive {:volt_hmr, :update, %{path: "logo.svg", changes: [:full]}}, 1000
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

    test "watcher invalidates CSS files when referenced assets change" do
      source_dir = Path.join(@fixture_dir, "src")
      app_css_path = Path.join(source_dir, "style.css")
      logo_path = Path.join(source_dir, "images/logo.svg")
      Registry.register(Volt.HMR.Registry, :clients, nil)

      File.mkdir_p!(Path.dirname(logo_path))
      File.write!(logo_path, "<svg>red</svg>")
      File.write!(app_css_path, ".logo { background: url('./images/logo.svg') }")
      File.touch!(app_css_path, {{2026, 1, 1}, {0, 0, 0}})
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 0}})

      conn = call_dev_server("/assets/style.css?import")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/images/logo.svg"

      File.write!(logo_path, "<svg>green</svg>")
      File.touch!(logo_path, {{2026, 1, 1}, {0, 0, 1}})

      watcher =
        start_supervised!({Volt.Watcher, root: source_dir, name: :test_css_asset_dependents})

      send(watcher, {:file_event, self(), {logo_path, [:modified]}})
      _ = :sys.get_state(watcher)

      assert_receive {:volt_hmr, :update, %{path: "images/logo.svg", changes: [:full]}}, 1000
      assert_receive {:volt_hmr, :update, %{path: "style.css", changes: [:style]}}, 1000
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
end
