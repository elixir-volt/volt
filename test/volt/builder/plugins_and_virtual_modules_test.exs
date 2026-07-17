defmodule Volt.Builder.PluginsAndVirtualModulesTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 plugins and virtual modules" do
    test "eager import.meta.glob dependencies resolve from original source directory" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/components"))

      File.write!(Path.join(@fixture_dir, "src/components/One.vue"), """
      <script setup lang=\"ts\">
      const message: string = 'one'
      </script>
      <template><p>{{ message }}</p></template>
      """)

      File.write!(Path.join(@fixture_dir, "src/glob_app.ts"), """
      const components = import.meta.glob('./components/**/*.vue', { eager: true })
      console.log(Object.keys(components))
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/glob_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.expand("../node_modules", __DIR__)
        )

      assert File.read!(result.js.path) =~ "One.vue"
    end

    test "copies public directory files to static root" do
      public_dir = Path.join(@fixture_dir, "public")
      File.mkdir_p!(Path.join(public_dir, "nested"))
      File.write!(Path.join(public_dir, "favicon.svg"), "<svg>public</svg>")
      File.write!(Path.join(public_dir, "nested/robots.txt"), "User-agent: *")

      {:ok, _result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: Path.join(@outdir, "js"),
          public_dir: public_dir,
          minify: false,
          sourcemap: false
        )

      assert File.read!(Path.join(@outdir, "favicon.svg")) == "<svg>public</svg>"
      assert File.read!(Path.join(@outdir, "nested/robots.txt")) == "User-agent: *"
    end

    test "dynamic import vars preserve asset query modules" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/messages"))
      File.write!(Path.join(@fixture_dir, "src/messages/home.txt"), "hello dynamic raw")

      File.write!(Path.join(@fixture_dir, "src/dynamic_raw_app.ts"), """
      const name = 'home'
      import(`./messages/${name}.txt?raw`).then((mod) => console.log(mod.default))
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_raw_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          code_splitting: false
        )

      js = File.read!(result.js.path)
      assert js =~ "hello dynamic raw"
      refute js =~ "import.meta.glob"
    end

    test "dynamic import vars compile into production graph modules" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/pages"))
      File.write!(Path.join(@fixture_dir, "src/pages/home.ts"), "export const name = 'home'")
      File.write!(Path.join(@fixture_dir, "src/pages/about.ts"), "export const name = 'about'")

      File.write!(Path.join(@fixture_dir, "src/dynamic_app.ts"), """
      const page = 'home'
      import(`./pages/${page}.ts`).then((mod) => console.log(mod.name))
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          code_splitting: false
        )

      js = File.read!(result.js.path)
      assert js =~ "home"
      assert js =~ "about"
      assert js =~ "Unknown variable dynamic import"
      refute js =~ "import.meta.glob"
    end

    test "new URL asset references compile through production asset modules" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(Path.join(@fixture_dir, "src/asset_url_app.ts"), """
      const logo = new URL('./logo.svg', import.meta.url).href
      console.log(logo)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/asset_url_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ ~r(/assets/logo-[a-f0-9]{8}\.svg)
      refute js =~ "./logo.svg"
    end

    test "asset URL prefix config applies to production asset modules" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(Path.join(@fixture_dir, "src/asset_prefix_app.ts"), """
      import url from './logo.svg?url'
      console.log(url)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/asset_prefix_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          asset_url_prefix: "https://cdn.example.com/assets/"
        )

      js = File.read!(result.js.path)
      assert js =~ ~r(https://cdn\.example\.com/assets/logo-[a-f0-9]{8}\.svg)
      refute js =~ "https:/cdn.example.com"
    end

    test "asset query imports compile as distinct production modules" do
      File.write!(Path.join(@fixture_dir, "src/message.txt"), "hello from raw")
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(Path.join(@fixture_dir, "src/asset_query_app.ts"), """
      import raw from './message.txt?raw'
      import url from './logo.svg?url'
      console.log(raw, url)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/asset_query_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "hello from raw"
      assert js =~ ~r(/assets/logo-[a-f0-9]{8}\.svg)
      refute js =~ "data:image/svg+xml"
    end

    test "eager import.meta.glob inside Vue SFC is included in production graph" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/pages"))
      File.write!(Path.join(@fixture_dir, "src/pages/home.ts"), "export const page = 'home'")

      File.write!(Path.join(@fixture_dir, "src/App.vue"), """
      <script setup lang=\"ts\">
      const pages = import.meta.glob('./pages/*.ts', { eager: true })
      console.log(pages)
      </script>
      <template><p>App</p></template>
      """)

      File.write!(Path.join(@fixture_dir, "src/app.ts"), """
      import App from './App.vue'
      console.log(App)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.expand("../node_modules", __DIR__)
        )

      js = File.read!(result.js.path)
      assert js =~ "home"
      refute js =~ "import.meta.glob"
    end

    test "alias-imported Vue SFC resolves bare npm imports" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/components"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/fake-lib"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/fake-lib/package.json"),
        ~s({"name":"fake-lib","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/fake-lib/index.js"),
        "export const widget = 'fake-widget';\n"
      )

      File.write!(Path.join(@fixture_dir, "src/components/Widget.vue"), """
      <template><div>Widget</div></template>
      <script setup>
      import { widget } from 'fake-lib'
      console.log(widget)
      </script>
      """)

      File.write!(Path.join(@fixture_dir, "src/alias_app.ts"), """
      import Widget from '@components/Widget.vue'
      console.log(Widget)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/alias_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          aliases: %{"@components" => Path.join(@fixture_dir, "src/components")},
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "fake-widget"
    end

    test "plugin content_type overrides file extension dispatch" do
      File.write!(Path.join(@fixture_dir, "src/data.custom"), """
      export const value = 42;
      """)

      File.write!(Path.join(@fixture_dir, "src/plugin_app.ts"), """
      import { value } from './data.custom'
      console.log(value)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/plugin_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          plugins: [JSLoaderPlugin]
        )

      js = File.read!(result.js.path)
      assert js =~ "42"
    end

    test "virtual modules resolved and loaded via plugins" do
      File.write!(Path.join(@fixture_dir, "src/virtual_app.ts"), """
      import val from 'my-virtual'
      console.log(val)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/virtual_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          plugins: [VirtualModPlugin]
        )

      js = File.read!(result.js.path)
      assert js =~ "99"
    end

    test "virtual modules can be used as build entries" do
      {:ok, result} =
        Volt.Builder.build(
          entry: "virtual-entry",
          outdir: @outdir,
          name: "virtual-entry",
          hash: false,
          minify: false,
          sourcemap: false,
          plugins: [VirtualModPlugin]
        )

      js = File.read!(result.js.path)
      assert Path.basename(result.js.path) == "virtual-entry.js"
      assert js =~ "99"
    end

    test "extensionless virtual modules default to JavaScript" do
      {:ok, result} =
        Volt.Builder.build(
          entry: "virtual:plain",
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false,
          plugins: [VirtualModPlugin]
        )

      assert result.manifest["virtual_plain.js"].file == "virtual_plain.js"
      assert File.read!(Path.join(@outdir, "virtual_plain.js")) =~ "123"
    end

    test "multiple virtual build entries get stable manifest keys" do
      {:ok, result} =
        Volt.Builder.build(
          entry: ["virtual:site/entry-a", "virtual:site/entry-b"],
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false,
          plugins: [VirtualModPlugin]
        )

      assert Map.has_key?(result.manifest, "entry-a.js")
      assert Map.has_key?(result.manifest, "entry-b.js")
      assert result.manifest["entry-a.js"].file == "entry-a.js"
      assert result.manifest["entry-b.js"].file == "entry-b.js"
    end

    test "virtual build entries can import stylesheet dependencies" do
      File.write!(Path.join(@fixture_dir, "src/style.css"), ".foo { color: red }")

      {:ok, result} =
        Volt.Builder.build(
          entry: "virtual:site/style-entry",
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false,
          plugins: [VirtualModPlugin]
        )

      assert result.manifest["style-entry.js"].css == ["style-entry.css"]
      assert File.read!(Path.join(@outdir, "style-entry.css")) =~ ".foo"
    end
  end
end
