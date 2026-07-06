defmodule Volt.DevServer.FrameworksTest do
  use Volt.TestSupport.DevServerCase

  describe "Vue SFCs" do
    test "serves compiled Vue SFC" do
      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200
      assert conn.resp_body =~ "msg"
    end

    test "serves Vue style blocks through self-imported embedded CSS modules" do
      File.write!(Path.join(@fixture_dir, "src/App.vue"), """
      <template><div class="my-widget">{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.my-widget { color: rebeccapurple }</style>
      """)

      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200

      assert [style_url] =
               Regex.run(~r{/assets/App\.vue\?[^"']*type=style[^"']*}, conn.resp_body)

      style_conn = call_dev_server(style_url)
      assert style_conn.status == 200
      assert style_conn.resp_body =~ ".my-widget"
      assert style_conn.resp_body =~ "#639"
      assert style_conn.resp_body =~ "__volt_updateStyle"
    end

    test "tracks Vue style asset dependencies" do
      logo_path = Path.join(@fixture_dir, "src/logo.svg")
      vue_path = Path.join(@fixture_dir, "src/App.vue")

      File.write!(logo_path, "<svg></svg>")

      File.write!(vue_path, """
      <template><div class="logo">{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      conn = call_dev_server("/assets/App.vue")

      assert conn.status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [vue_path]
    end

    test "removes stale Vue style asset dependencies" do
      logo_path = Path.join(@fixture_dir, "src/logo.svg")
      vue_path = Path.join(@fixture_dir, "src/App.vue")

      File.write!(logo_path, "<svg></svg>")

      File.write!(vue_path, """
      <template><div class="logo">{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 0}})
      assert call_dev_server("/assets/App.vue").status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [vue_path]

      File.write!(vue_path, """
      <template><div>{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      """)

      File.touch!(vue_path, {{2026, 1, 1}, {0, 0, 1}})
      assert call_dev_server("/assets/App.vue").status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == []
      assert Volt.HMR.StyleGraph.dependencies_of(vue_path) == []
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

  describe "Svelte components" do
    test "tracks Svelte style asset dependencies" do
      logo_path = Path.join(@fixture_dir, "src/logo.svg")
      svelte_path = Path.join(@fixture_dir, "src/App.svelte")

      File.write!(logo_path, "<svg></svg>")

      File.write!(svelte_path, """
      <script>const msg = 'hi'</script>
      <div class="logo">{msg}</div>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      conn = call_dev_server("/assets/App.svelte")

      assert conn.status == 200
      assert Volt.HMR.StyleGraph.dependents(logo_path) == [svelte_path]
    end
  end
end
