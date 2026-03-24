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

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["main.js"]["css"] == [Path.basename(result.css.path)]
      assert manifest["main.css"]["assets"] == [Path.basename(result.css.path)]
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

    test "builds parent entry with worker syntax preserved" do
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
  end
end
