defmodule Volt.Builder.FrameworksTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 framework plugins" do
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
  end
end
