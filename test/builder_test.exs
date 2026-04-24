defmodule Volt.BuilderTest do
  use ExUnit.Case, async: false

  defmodule JSLoaderPlugin do
    @behaviour Volt.Plugin
    def name, do: "js-loader"
    def resolve(_, _), do: nil

    def load(path) do
      if String.ends_with?(path, ".custom") and File.regular?(path) do
        {:ok, File.read!(path), "application/javascript"}
      end
    end
  end

  defmodule VirtualModPlugin do
    @behaviour Volt.Plugin
    def name, do: "virtual-mod"
    def resolve("my-virtual", _), do: {:ok, "virtual:my-virtual"}
    def resolve(_, _), do: nil
    def load("virtual:my-virtual"), do: {:ok, "export default 99;", "application/javascript"}
    def load(_), do: nil
  end

  @fixture_dir Path.expand("fixtures/builder", __DIR__)
  @outdir Path.expand("fixtures/builder/dist", __DIR__)

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "src"))

    File.write!(Path.join(@fixture_dir, "src/utils.ts"), """
    export function greet(name: string): string {
      return `Hello, ${name}!`
    }
    """)

    File.write!(Path.join(@fixture_dir, "src/app.ts"), """
    import { greet } from './utils'
    console.log(greet('world'))
    """)

    on_exit(fn ->
      File.rm_rf!(@fixture_dir)
      File.rm_rf!(@outdir)
    end)

    :ok
  end

  describe "build/1" do
    test "bundles entry and dependencies" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      js = File.read!(result.js.path)
      assert js =~ "greet"
      assert js =~ "Hello"
    end

    test "generates content-hashed filenames" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      filename = Path.basename(result.js.path)
      assert filename =~ ~r/^app-[a-f0-9]{8}\.js$/
    end

    test "supports ESM output for SSR/library entries" do
      File.write!(
        Path.join(@fixture_dir, "src/server.ts"),
        "export function render() { return 'ok' }"
      )

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/server.ts"),
          outdir: @outdir,
          name: "server",
          format: :esm,
          minify: false,
          sourcemap: false,
          code_splitting: false,
          hash: false
        )

      js = File.read!(result.js.path)
      assert js =~ "export { render }"
      refute js =~ "return exports"
    end

    test "writes manifest.json" do
      {:ok, _result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      manifest_path = Path.join(@outdir, "manifest.json")
      assert File.regular?(manifest_path)
      manifest = manifest_path |> File.read!() |> :json.decode()
      assert Map.has_key?(manifest, "app.js")
      assert manifest["app.js"]["file"] =~ ~r/^app-[a-f0-9]{8}\.js$/
    end

    test "minifies by default" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      refute js =~ "\n  "
    end

    test "sourcemap appends sourceMappingURL comment" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: true
        )

      map_path = result.js.path <> ".map"
      assert File.regular?(map_path)
      map = map_path |> File.read!() |> :json.decode()
      assert map["version"] == 3

      js = File.read!(result.js.path)
      js_filename = Path.basename(result.js.path)
      assert js =~ "//# sourceMappingURL=#{js_filename}.map"
    end

    test "hidden sourcemap writes .map file without URL comment" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: :hidden
        )

      map_path = result.js.path <> ".map"
      assert File.regular?(map_path)

      js = File.read!(result.js.path)
      refute js =~ "sourceMappingURL"
    end

    test "collects CSS from Vue SFCs" do
      File.write!(Path.join(@fixture_dir, "src/App.vue"), """
      <template><div class="box">hi</div></template>
      <script setup>console.log('app')</script>
      <style scoped>.box { color: red }</style>
      """)

      File.write!(Path.join(@fixture_dir, "src/main.ts"), """
      import './App.vue'
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/main.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert result.css != nil
      css = File.read!(result.css.path)
      assert css =~ "color"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["main.js"]["css"] == [Path.basename(result.css.path)]
      assert manifest["main.css"]["assets"] == [Path.basename(result.css.path)]
    end

    @tag :integration
    test "bundles Svelte components with runtime package resolution" do
      File.write!(Path.join(@fixture_dir, "src/App.svelte"), """
      <script>
        export let name = 'Volt'
      </script>

      <style>
        h1 { color: rebeccapurple }
      </style>

      <h1>Hello {name}</h1>
      """)

      File.write!(Path.join(@fixture_dir, "src/main.ts"), """
      import App from './App.svelte'
      console.log(App)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/main.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      js = File.read!(result.js.path)
      assert js =~ "Hello"
      assert js =~ "template_effect"

      assert result.css != nil
      assert File.read!(result.css.path) =~ "#639"
    end

    test "builds standalone CSS entries from HTML manifests" do
      File.write!(Path.join(@fixture_dir, "src/site.css"), ".site { color: blue }")

      File.write!(Path.join(@fixture_dir, "src/index.html"), """
      <html>
        <head>
          <link rel="stylesheet" href="./site.css">
        </head>
        <body></body>
      </html>
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/index.html"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert result.css != nil
      assert File.regular?(result.css.path)

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["site.css"]["file"] =~ ~r/^site-[a-f0-9]{8}\.css$/
      assert manifest["site.css"]["assets"] == [manifest["site.css"]["file"]]
    end

    test "builds worker entry as a standalone bundle" do
      File.write!(Path.join(@fixture_dir, "src/worker.ts"), "self.postMessage('ready')")

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      assert Path.basename(result.js.path) =~ ~r/^worker-[a-f0-9]{8}\.js$/
    end

    test "rewrites worker URL to hashed filename in parent bundle" do
      File.write!(Path.join(@fixture_dir, "src/worker.ts"), "self.postMessage('ready')")

      File.write!(Path.join(@fixture_dir, "src/worker_app.ts"), """
      const worker = new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      console.log(worker)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      js = File.read!(result.js.path)
      assert js =~ "new Worker"
      assert js =~ ~r/worker-[a-f0-9]{8}\.js/

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert Map.has_key?(manifest, "worker_app.js")
    end

    test "accepts custom name" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          name: "bundle",
          minify: false,
          sourcemap: false
        )

      assert Path.basename(result.js.path) =~ "bundle-"
    end

    test "returns error for missing entry" do
      {:error, _} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/missing.ts"),
          outdir: @outdir
        )
    end

    test "external imports become global access in IIFE" do
      File.write!(Path.join(@fixture_dir, "src/vue_app.ts"), """
      import { ref, computed } from 'vue'
      const count = ref(0)
      const double = computed(() => count.value * 2)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/vue_app.ts"),
          outdir: @outdir,
          external: ["vue"],
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "const { ref, computed } = Vue;"
      assert js =~ "ref(0)"
      refute js =~ ~s(from 'vue')
    end

    test "external with explicit global name" do
      File.write!(Path.join(@fixture_dir, "src/ext_app.ts"), """
      import { ref } from 'vue'
      ref(0)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/ext_app.ts"),
          outdir: @outdir,
          external: %{"vue" => "MyVue"},
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "const { ref } = MyVue;"
    end

    test "manual chunks split modules into separate files" do
      lib_dir = Path.join(@fixture_dir, "src/lib")
      File.mkdir_p!(lib_dir)

      File.write!(Path.join(lib_dir, "helpers.ts"), """
      export function helper() { return 'help' }
      """)

      File.write!(Path.join(@fixture_dir, "src/chunked.ts"), """
      import { helper } from './lib/helpers'
      console.log(helper())
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/chunked.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          chunks: %{"lib" => [Path.join(@fixture_dir, "src/lib")]}
        )

      assert result.chunks != nil
      chunk_files = Enum.map(result.chunks, &Path.basename(&1.path))
      assert Enum.any?(chunk_files, &(&1 =~ "lib"))
    end

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

    test "same-name files in different directories get unique labels" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/a"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/b"))

      File.write!(Path.join(@fixture_dir, "src/a/index.js"), "export const a = 1;")
      File.write!(Path.join(@fixture_dir, "src/b/index.js"), "export const b = 2;")

      File.write!(Path.join(@fixture_dir, "src/dup_app.ts"), """
      import { a } from './a/index.js'
      import { b } from './b/index.js'
      console.log(a, b)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dup_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "1"
      assert js =~ "2"
    end

    test "shared dependencies imported by multiple modules are not duplicated" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/shared-lib"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/lib-a"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/lib-b"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/shared-lib/package.json"),
        ~s({"name":"shared-lib","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/shared-lib/index.js"),
        "export const shared = 'shared-value';\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-a/package.json"),
        ~s({"name":"lib-a","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-a/index.js"),
        "import { shared } from 'shared-lib';\nexport const a = 'a-' + shared;\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-b/package.json"),
        ~s({"name":"lib-b","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-b/index.js"),
        "import { shared } from 'shared-lib';\nexport const b = 'b-' + shared;\n"
      )

      File.write!(Path.join(@fixture_dir, "src/shared_app.ts"), """
      import { a } from 'lib-a'
      import { b } from 'lib-b'
      console.log(a, b)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/shared_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "shared-value"
      assert js =~ "a-"
      assert js =~ "b-"
    end

    test "loaders option enables JSX in .js files" do
      File.write!(Path.join(@fixture_dir, "src/jsx_app.js"), """
      const App = () => <div>Hello</div>
      export default App
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/jsx_app.js"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          loaders: %{".js" => "jsx"}
        )

      js = File.read!(result.js.path)
      assert js =~ "Hello"
    end

    test "collects CJS require() as imports" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/cjs-dep"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/cjs-dep/package.json"),
        ~s({"name":"cjs-dep","main":"index.js"})
      )

      File.write!(Path.join(@fixture_dir, "node_modules/cjs-dep/index.js"), """
      var helper = require('./helper')
      module.exports = helper
      """)

      File.write!(Path.join(@fixture_dir, "node_modules/cjs-dep/helper.js"), """
      module.exports = { value: 'cjs-works' }
      """)

      File.write!(Path.join(@fixture_dir, "src/cjs_app.ts"), """
      import dep from 'cjs-dep'
      console.log(dep.value)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/cjs_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "cjs-works"
    end

    test "resolves package subpath without exports field" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/subpath-pkg/lib"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/package.json"),
        ~s({"name":"subpath-pkg","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/index.js"),
        "module.exports = 'root'\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/lib/utils.js"),
        "export const util = 'subpath-util'\n"
      )

      File.write!(Path.join(@fixture_dir, "src/subpath_app.ts"), """
      import { util } from 'subpath-pkg/lib/utils'
      console.log(util)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/subpath_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "subpath-util"
    end

    test "skips .d.ts type declaration imports" do
      File.write!(Path.join(@fixture_dir, "src/types.d.ts"), """
      export type Foo = string
      """)

      File.write!(Path.join(@fixture_dir, "src/dts_app.ts"), """
      import { Foo } from './types'
      const x: Foo = 'hello'
      console.log(x)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "hello"
    end

    test "skips CSS imports in JS files" do
      File.write!(Path.join(@fixture_dir, "src/app.css"), "body { color: red }")

      File.write!(Path.join(@fixture_dir, "src/css_app.ts"), """
      import './app.css'
      console.log('loaded')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/css_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "loaded"
      refute js =~ "color"
    end

    test "strips TypeScript from Vue SFCs with lang=ts" do
      File.write!(Path.join(@fixture_dir, "src/TsComponent.vue"), """
      <template><div>{{ msg }}</div></template>
      <script setup lang="ts">
      import { ref, type Ref } from 'vue'
      const msg: Ref<string> = ref('typed')
      </script>
      """)

      File.write!(Path.join(@fixture_dir, "src/vue_ts_app.ts"), """
      import TsComponent from './TsComponent.vue'
      console.log(TsComponent)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/vue_ts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          external: ["vue"]
        )

      js = File.read!(result.js.path)
      refute js =~ "Ref<string>"
      assert js =~ "ref("
    end

    test "resolves .js imports to .ts files when .js does not exist" do
      File.write!(Path.join(@fixture_dir, "src/utils.ts"), """
      export const helper = 'ts-resolved'
      """)

      File.write!(Path.join(@fixture_dir, "src/js_to_ts_app.ts"), """
      import { helper } from './utils.js'
      console.log(helper)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/js_to_ts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "ts-resolved"
    end
  end
end
