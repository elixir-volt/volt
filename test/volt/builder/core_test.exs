defmodule Volt.Builder.CoreTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 core behavior" do
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

    test "embedded modules participate in the production graph" do
      File.write!(Path.join(@fixture_dir, "src/Card.box"), """
      <style>.card { color: red }</style>
      <script>const answer: number = 42; console.log(answer)</script>
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/Card.box"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false,
          plugins: [EmbeddedBoxPlugin]
        )

      js = File.read!(result.js.path)
      css = File.read!(result.css.path)

      assert js =~ "console.log(42)"
      assert css =~ "color: red"
    end

    test "style entry bundles nested CSS imports" do
      File.write!(Path.join(@fixture_dir, "src/tokens.css"), ":root { --brand: #639 }")

      File.write!(
        Path.join(@fixture_dir, "src/theme.css"),
        "@import './tokens.css';\n.button { color: var(--brand) }"
      )

      File.write!(
        Path.join(@fixture_dir, "src/styles.css"),
        "@import './theme.css';\n.app { display: grid }"
      )

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/styles.css"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert result.js == []
      assert Path.basename(result.css.path) == "styles.css"

      css = File.read!(result.css.path)
      assert css =~ "--brand"
      assert css =~ "button"
      assert css =~ "display: grid"
      refute css =~ "@import"

      manifest = @outdir |> Path.join("manifest.json") |> File.read!() |> :json.decode()
      assert manifest["styles.css"]["file"] == "styles.css"
      assert manifest["styles.css"]["assets"] == ["styles.css"]
    end

    test "builds SCSS style entries with relative partials" do
      File.write!(Path.join(@fixture_dir, "src/_tokens.scss"), "$brand: #639;")

      File.write!(
        Path.join(@fixture_dir, "src/styles.scss"),
        "@use 'tokens' as *; .button { color: $brand; &:hover { opacity: .8; } }"
      )

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/styles.scss"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert result.js == []
      assert Path.basename(result.css.path) == "styles.css"
      css = File.read!(result.css.path)
      assert css =~ "#639"
      assert css =~ ".button:hover"
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
  end
end
