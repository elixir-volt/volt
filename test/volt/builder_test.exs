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

    test "single bundle emits JS asset imports and records them in manifest" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg><path /></svg>")

      File.write!(Path.join(@fixture_dir, "src/asset_app.ts"), """
      import logo from './logo.svg?url'
      document.body.dataset.logo = logo
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/asset_app.ts"),
          outdir: @outdir,
          name: "asset-app",
          hash: false,
          minify: false,
          sourcemap: false
        )

      manifest = @outdir |> Path.join("manifest.json") |> File.read!() |> :json.decode()
      [asset] = manifest["asset-app.js"]["assets"]

      assert asset =~ ~r/logo-[a-f0-9]{8}\.svg/
      assert File.regular?(Path.join(@outdir, asset))
      assert File.read!(result.js.path) =~ "/assets/#{asset}"
      assert manifest["logo.svg"]["file"] == asset
    end

    test "multi-entry builds write one merged manifest" do
      File.write!(Path.join(@fixture_dir, "src/admin.ts"), "console.log('admin')")

      {:ok, result} =
        Volt.Builder.build(
          entry: [Path.join(@fixture_dir, "src/app.ts"), Path.join(@fixture_dir, "src/admin.ts")],
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false
        )

      manifest = @outdir |> Path.join("manifest.json") |> File.read!() |> :json.decode()

      assert Map.has_key?(manifest, "app.js")
      assert Map.has_key?(manifest, "admin.js")
      assert length(result.js) == 2
    end

    test "worker build errors fail the parent build" do
      File.write!(Path.join(@fixture_dir, "src/bad-worker.ts"), "export const =")

      File.write!(Path.join(@fixture_dir, "src/worker_parent.ts"), """
      new Worker(new URL('./bad-worker.ts', import.meta.url), { type: 'module' })
      """)

      assert {:error, _reason} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/worker_parent.ts"),
                 outdir: @outdir,
                 hash: false,
                 minify: false,
                 sourcemap: false
               )
    end

    test "empty entry builds without sourcemap when Rolldown omits one" do
      File.write!(Path.join(@fixture_dir, "src/empty.js"), "")

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/empty.js"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: true
        )

      assert File.regular?(result.js.path)
      refute File.exists?(result.js.path <> ".map")
    end

    test "tree-shakes unused exports by default" do
      File.write!(Path.join(@fixture_dir, "src/tree.ts"), """
      export function used() { return 'used' }
      export function unused() { return 'unused' }
      """)

      File.write!(Path.join(@fixture_dir, "src/tree-app.ts"), """
      import { used } from './tree'
      console.log(used())
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/tree-app.ts"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "used"
      refute js =~ "unused"
    end

    test "uses configured env prefix" do
      File.write!(
        Path.join(@fixture_dir, ".env"),
        "VITE_API=http://vite.test\nVOLT_API=http://volt.test\n"
      )

      File.write!(Path.join(@fixture_dir, "src/env-app.ts"), """
      console.log(import.meta.env.VITE_API)
      console.log(import.meta.env.VOLT_API)
      """)

      previous_cwd = File.cwd!()

      try do
        File.cd!(@fixture_dir)

        {:ok, result} =
          Volt.Builder.build(
            entry: Path.join(@fixture_dir, "src/env-app.ts"),
            outdir: @outdir,
            hash: false,
            minify: false,
            sourcemap: false,
            env_prefix: "VITE_"
          )

        js = File.read!(result.js.path)
        assert js =~ "http://vite.test"
        refute js =~ "http://volt.test"
      after
        File.cd!(previous_cwd)
      end
    end

    test "tree shaking option is accepted" do
      File.write!(Path.join(@fixture_dir, "src/tree.ts"), """
      export function used() { return 'used' }
      export function unused() { return 'unused' }
      """)

      File.write!(Path.join(@fixture_dir, "src/tree-app.ts"), """
      import { used } from './tree'
      console.log(used())
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/tree-app.ts"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false,
          tree_shaking: false
        )

      js = File.read!(result.js.path)
      assert js =~ "used"
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

    @tag :integration
    test "bundles Solid TSX through configured plugin" do
      solid_dir = Path.join(@fixture_dir, "node_modules/solid-js")
      File.mkdir_p!(solid_dir)

      File.write!(
        Path.join(solid_dir, "package.json"),
        :json.encode(%{
          "name" => "solid-js",
          "type" => "module",
          "exports" => %{
            "." => "./index.js",
            "./web" => "./web.js"
          }
        })
      )

      File.write!(Path.join(solid_dir, "index.js"), """
      export function createSignal(value) {
        return [() => value, (next) => { value = typeof next === 'function' ? next(value) : next }]
      }
      """)

      File.write!(Path.join(solid_dir, "web.js"), """
      export function template(html) { return () => ({ marker: 'solid-web-template', html }) }
      export function insert() {}
      export function delegateEvents() {}
      export function render(fn) { return fn() }
      export function createComponent(Component, props) { return Component(props) }
      """)

      File.write!(
        Path.join(@fixture_dir, "src/solid_worker.ts"),
        "self.postMessage('solid-worker-ready')"
      )

      File.write!(Path.join(@fixture_dir, "src/solid_types.ts"), "export type Label = string")

      File.write!(Path.join(@fixture_dir, "src/solid_app.tsx"), """
      import type { Label } from './solid_types'
      import { createSignal } from 'solid-js'
      import { render } from 'solid-js/web'

      const worker = new Worker(new URL('./solid_worker.ts', import.meta.url), { type: 'module' })
      console.log(worker)

      type Props = { name: Label }

      function App(props: Props) {
        const [count, setCount] = createSignal(0)
        return <button onClick={() => setCount(count() + 1)}>{props.name} {count()}</button>
      }

      render(() => <App name="Volt" />)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/solid_app.tsx"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules"),
          plugins: [Volt.Plugin.Solid]
        )

      js = File.read!(result.js.path)
      assert js =~ "solid-web-template"
      assert js =~ "$$click"
      assert js =~ ~r/solid_worker-[a-f0-9]{8}\.js/
      refute js =~ "jsx-runtime"
    end

    test "rewrites workers by importer path instead of basename" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/a"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/b"))

      File.write!(Path.join(@fixture_dir, "src/a/worker.ts"), "self.postMessage('worker-a')")
      File.write!(Path.join(@fixture_dir, "src/b/worker.ts"), "self.postMessage('worker-b')")

      File.write!(Path.join(@fixture_dir, "src/a/mod.ts"), """
      new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      """)

      File.write!(Path.join(@fixture_dir, "src/b/mod.ts"), """
      new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      """)

      File.write!(Path.join(@fixture_dir, "src/worker_collision_app.ts"), """
      export const loadA = () => import('./a/mod')
      export const loadB = () => import('./b/mod')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker_collision_app.ts"),
          outdir: @outdir,
          name: "worker-collision",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      worker_files = Path.wildcard(Path.join(@outdir, "worker-*.js"))

      chunk_sources =
        result.chunks
        |> Enum.reject(&(&1.type == :entry))
        |> Enum.map(fn chunk -> chunk.path |> File.read!() end)

      worker_refs =
        chunk_sources
        |> Enum.flat_map(&Regex.scan(~r/worker-[a-f0-9]{8}\.js/, &1))
        |> List.flatten()

      assert length(Enum.uniq(worker_refs)) == 2
      assert Enum.all?(worker_refs, &File.regular?(Path.join(@outdir, &1)))
      assert Enum.any?(worker_files, &(File.read!(&1) =~ "worker-a"))
      assert Enum.any?(worker_files, &(File.read!(&1) =~ "worker-b"))
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

    test "code splitting keeps entry bundle when entry has dynamic import" do
      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/dynamic_entry.ts"), """
      const $volt_ = (value: string) => value.toUpperCase()
      document.body.dataset.entry = $volt_('dynamic-entry')

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_entry.ts"),
          outdir: @outdir,
          name: "dynamic-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      assert Path.basename(result.js.path) == "dynamic-entry.js"

      entry_js = File.read!(Path.join(@outdir, "dynamic-entry.js"))
      assert entry_js =~ "dynamic-entry"
      assert entry_js =~ ~r/import\(["']\.\/dynamic-entry-lazy\.js["']\)/
      assert entry_js =~ "$volt_("
      refute entry_js =~ "import(\"dynamic-entry\")"

      lazy_js = File.read!(Path.join(@outdir, "dynamic-entry-lazy.js"))
      assert lazy_js =~ "lazy-loaded"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["dynamic-entry.js"]["file"] == "dynamic-entry.js"
      assert manifest["dynamic-entry.js"]["isEntry"]
      assert manifest["dynamic-entry.js"]["dynamicImports"] == ["dynamic-entry-lazy.js"]
      assert manifest["dynamic-entry-lazy.js"]["file"] == "dynamic-entry-lazy.js"
      refute manifest["dynamic-entry-lazy.js"]["isEntry"]
    end

    test "code splitting records async chunk css in manifest and preloads it" do
      File.write!(Path.join(@fixture_dir, "src/lazy.css"), ".lazy { color: red }")

      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      import './lazy.css'
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/dynamic_css_entry.ts"), """
      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_css_entry.ts"),
          outdir: @outdir,
          name: "dynamic-css-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      assert entry_js =~ "__voltPreload"
      assert entry_js =~ "./dynamic-css-entry-lazy.css"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["dynamic-css-entry-lazy.js"]["css"] == ["dynamic-css-entry-lazy.css"]
      assert manifest["dynamic-css-entry.js"]["dynamicImports"] == ["dynamic-css-entry-lazy.js"]
      assert File.read!(Path.join(@outdir, "dynamic-css-entry-lazy.css")) =~ "lazy"
    end

    test "hashed code splitting keeps dynamic preload URLs and manifest files in sync" do
      File.write!(Path.join(@fixture_dir, "src/common.css"), ".common { color: blue }")
      File.write!(Path.join(@fixture_dir, "src/lazy-a.css"), ".lazy-a { color: red }")

      File.write!(Path.join(@fixture_dir, "src/shared.ts"), """
      import './common.css'
      export const shared = 'shared-value'
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy-a.ts"), """
      import { shared } from './shared'
      import './lazy-a.css'
      export const value = 'a-' + shared
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy-b.ts"), """
      import { shared } from './shared'
      export const value = 'b-' + shared
      """)

      File.write!(Path.join(@fixture_dir, "src/hashed_preload_entry.ts"), """
      export const loadA = () => import('./lazy-a')
      export const loadB = () => import('./lazy-b')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/hashed_preload_entry.ts"),
          outdir: @outdir,
          name: "hashed-preload",
          format: :esm,
          hash: true,
          minify: false,
          sourcemap: false
        )

      manifest = @outdir |> Path.join("manifest.json") |> File.read!() |> :json.decode()
      entry = manifest["hashed-preload.js"]
      entry_js = File.read!(result.js.path)

      assert entry["file"] == Path.basename(result.js.path)
      assert entry["dynamicImports"] |> Enum.sort() == entry["dynamicImports"]

      for {_key, %{"file" => file} = item} <- manifest do
        assert File.regular?(Path.join(@outdir, file))

        for css <- Map.get(item, "css", []) do
          assert File.regular?(Path.join(@outdir, css))
        end

        for asset <- Map.get(item, "assets", []) do
          assert File.regular?(Path.join(@outdir, asset))
        end
      end

      lazy_a = Enum.find(entry["dynamicImports"], &String.contains?(&1, "lazy-a"))
      lazy_b = Enum.find(entry["dynamicImports"], &String.contains?(&1, "lazy-b"))
      common = manifest[lazy_a]["imports"] |> List.first()
      common_css = manifest[common]["css"] |> List.first()
      lazy_css = manifest[lazy_a]["css"] |> List.first()

      assert entry_js =~ lazy_a
      assert entry_js =~ lazy_b
      assert entry_js =~ common
      assert entry_js =~ common_css
      assert entry_js =~ lazy_css
      assert File.read!(Path.join(@outdir, common_css)) =~ "common"
      assert File.read!(Path.join(@outdir, lazy_css)) =~ "lazy-a"
    end

    test "code splitting keeps dynamic facade when a module is also statically imported" do
      File.write!(Path.join(@fixture_dir, "src/facade.ts"), "export const value = 'facade-value'")

      File.write!(Path.join(@fixture_dir, "src/facade_entry.ts"), """
      import { value } from './facade'
      document.body.dataset.eager = value
      import('./facade').then((mod) => {
        document.body.dataset.lazy = mod.value
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/facade_entry.ts"),
          outdir: @outdir,
          name: "facade-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      async_js = File.read!(Path.join(@outdir, "facade-entry-facade.js"))

      assert entry_js =~ ~r/import\s*\{\s*value\s*\}\s*from\s*["']\.\/facade-entry-facade\.js["']/
      assert entry_js =~ ~r/import\(["']\.\/facade-entry-facade\.js["']\)/
      assert async_js =~ "facade-value"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["facade-entry.js"]["isEntry"]
      assert manifest["facade-entry-facade.js"]["isEntry"] == false
      assert manifest["facade-entry.js"]["imports"] == ["facade-entry-facade.js"]
      assert manifest["facade-entry.js"]["dynamicImports"] == ["facade-entry-facade.js"]
    end

    test "code splitting rewrites chunk imports by exact virtual specifier" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/one/collide"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/two/collide"))

      File.write!(
        Path.join(@fixture_dir, "src/one/collide/index.ts"),
        "export const value = 'one-collide'"
      )

      File.write!(
        Path.join(@fixture_dir, "src/two/collide/index.ts"),
        "export const value = 'two-collide'"
      )

      File.write!(Path.join(@fixture_dir, "src/collision_entry.ts"), """
      export const loadOne = () => import('./one/collide')
      export const loadTwo = () => import('./two/collide')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/collision_entry.ts"),
          outdir: @outdir,
          name: "collision-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      chunk_files = result.chunks |> Enum.map(&Path.basename(&1.path)) |> Enum.sort()
      one_file = Enum.find(chunk_files, &(File.read!(Path.join(@outdir, &1)) =~ "one-collide"))
      two_file = Enum.find(chunk_files, &(File.read!(Path.join(@outdir, &1)) =~ "two-collide"))

      assert entry_js =~ one_file
      assert entry_js =~ two_file
      assert File.read!(Path.join(@outdir, one_file)) =~ "one-collide"
      assert File.read!(Path.join(@outdir, two_file)) =~ "two-collide"
    end

    test "code splitting rewrites minified dynamic import chunk URLs" do
      File.write!(
        Path.join(@fixture_dir, "src/lazy.ts"),
        "export const lazyValue = 'lazy-loaded'"
      )

      File.write!(Path.join(@fixture_dir, "src/minified_dynamic_entry.ts"), """
      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/minified_dynamic_entry.ts"),
          outdir: @outdir,
          name: "minified-dynamic-entry",
          format: :esm,
          hash: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "minified-dynamic-entry.js"))
      assert entry_js =~ "minified-dynamic-entry-lazy.js"
      refute entry_js =~ "lazy.ts"
      refute entry_js =~ ~r/import\([`'"]\.\/lazy[`'"]\)/
    end

    test "dynamic import protection avoids user identifier collisions" do
      File.write!(
        Path.join(@fixture_dir, "src/lazy.ts"),
        "export const lazyValue = 'lazy-loaded'"
      )

      File.write!(Path.join(@fixture_dir, "src/placeholder_collision_entry.ts"), """
      function __volt_dynamic_import__0__(value: string) {
        return value
      }

      document.body.dataset.placeholder = __volt_dynamic_import__0__('kept')

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/placeholder_collision_entry.ts"),
          outdir: @outdir,
          name: "placeholder-collision-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "placeholder-collision-entry.js"))
      assert entry_js =~ "function __volt_dynamic_import__0__"
      refute entry_js =~ "function import"
      assert entry_js =~ ~r/import\([`'"]\.\/placeholder-collision-entry-lazy\.js[`'"]\)/
    end

    test "code splitting includes alias modules outside the entry root" do
      File.mkdir_p!(Path.join(@fixture_dir, "shared"))

      File.write!(Path.join(@fixture_dir, "shared/rendered.ts"), """
      export const rendered = 'rendered-from-shared-root'
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/external_alias_entry.ts"), """
      import { rendered } from '@shared/rendered'

      document.body.dataset.rendered = rendered

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/external_alias_entry.ts"),
          outdir: @outdir,
          name: "external-alias-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false,
          aliases: %{"@shared" => Path.join(@fixture_dir, "shared")}
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "external-alias-entry.js"))
      assert entry_js =~ "rendered-from-shared-root"
      assert entry_js =~ ~r/import\(["']\.\/external-alias-entry-lazy\.js["']\)/

      lazy_js = File.read!(Path.join(@outdir, "external-alias-entry-lazy.js"))
      assert lazy_js =~ "lazy-loaded"
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

    test "rewrites bare CJS require() to the bundled module (no runtime require leak)" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/bare-cjs-dep"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/cjs-consumer"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/bare-cjs-dep/package.json"),
        ~s({"name":"bare-cjs-dep","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/bare-cjs-dep/index.js"),
        "module.exports = { token: 'bundled-bare-cjs' }\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/cjs-consumer/package.json"),
        ~s({"name":"cjs-consumer","main":"index.js"})
      )

      # A CJS module that requires another package by bare name — mirrors
      # react-dom's internal `require("scheduler")`.
      File.write!(Path.join(@fixture_dir, "node_modules/cjs-consumer/index.js"), """
      var dep = require('bare-cjs-dep')
      module.exports = dep.token
      """)

      File.write!(Path.join(@fixture_dir, "src/bare_cjs_app.ts"), """
      import token from 'cjs-consumer'
      console.log(token)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/bare_cjs_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      # The dependency is bundled in, and the bare `require()` is rewritten to the
      # bundled module rather than left as a runtime call that throws in browsers.
      assert js =~ "bundled-bare-cjs"
      refute js =~ ~r/require\(\s*[`"']bare-cjs-dep[`"']\s*\)/
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
