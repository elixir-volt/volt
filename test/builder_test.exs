defmodule Volt.BuilderTest do
  use ExUnit.Case, async: false

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

    test "generates sourcemap" do
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
  end
end
