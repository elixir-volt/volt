defmodule Volt.Builder.Output.CSSTest do
  use ExUnit.Case, async: false

  @fixture_dir Path.join(System.tmp_dir!(), "volt-builder-css-test")
  @outdir Path.join(@fixture_dir, "dist")

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "src"))

    on_exit(fn ->
      File.rm_rf!(@fixture_dir)
      File.rm_rf!(@outdir)
    end)

    :ok
  end

  describe "CSS production builds" do
    test "CSS-only JS entry builds with sourcemap enabled" do
      File.write!(Path.join(@fixture_dir, "src/styles.css"), "body { color: red; }")
      File.write!(Path.join(@fixture_dir, "src/css_only.js"), "import './styles.css'")

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/css_only.js"),
          outdir: @outdir,
          hash: false,
          minify: false,
          sourcemap: true
        )

      assert File.regular?(result.js.path)
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

    test "rewrites standalone CSS entry asset URLs" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(Path.join(@fixture_dir, "src/site.css"), """
      .site { background: url('./logo.svg') }
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/site.css"),
          outdir: @outdir,
          root: Path.join(@fixture_dir, "src"),
          minify: false,
          sourcemap: false
        )

      css = File.read!(result.css.path)
      assert css =~ ~r/url\("\/assets\/logo-[a-f0-9]{8}\.svg"\)/
      refute css =~ "./logo.svg"
      assert [asset_path] = Path.wildcard(Path.join(@outdir, "logo-*.svg"))

      asset_file = Path.basename(asset_path)
      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert asset_file in manifest["site.css"]["assets"]
      assert manifest["logo.svg"]["file"] == asset_file
    end

    test "rewrites CSS imported from JavaScript asset URLs" do
      File.write!(Path.join(@fixture_dir, "src/hero.png"), "hero")

      File.write!(Path.join(@fixture_dir, "src/app.css"), """
      .hero { background-image: image-set(url('./hero.png') 1x) }
      """)

      File.write!(Path.join(@fixture_dir, "src/css_asset_app.ts"), """
      import './app.css'
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/css_asset_app.ts"),
          outdir: @outdir,
          root: Path.join(@fixture_dir, "src"),
          minify: false,
          sourcemap: false
        )

      css = File.read!(result.css.path)
      assert css =~ ~r/\/assets\/hero-[a-f0-9]{8}\.png/
      refute css =~ "./hero.png"
      assert [asset_path] = Path.wildcard(Path.join(@outdir, "hero-*.png"))

      asset_file = Path.basename(asset_path)
      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert asset_file in manifest["css_asset_app.css"]["assets"]
      assert manifest["hero.png"]["file"] == asset_file
    end

    test "asset URL prefix config applies to production CSS asset URLs" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(
        Path.join(@fixture_dir, "src/prefixed.css"),
        ".logo { background: url('./logo.svg') }"
      )

      File.write!(Path.join(@fixture_dir, "src/prefixed.ts"), "import './prefixed.css'")

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/prefixed.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          asset_url_prefix: "https://cdn.example.com/assets/"
        )

      css = File.read!(result.css.path)
      assert css =~ ~r/https:\/\/cdn\.example\.com\/assets\/logo-[a-f0-9]{8}\.svg/
      refute css =~ "https:/cdn.example.com"
    end

    test "rewrites Vue SFC style asset URLs relative to the component" do
      File.write!(Path.join(@fixture_dir, "src/logo.svg"), "<svg></svg>")

      File.write!(Path.join(@fixture_dir, "src/App.vue"), """
      <template><div class=\"logo\">hi</div></template>
      <style>.logo { background: url('./logo.svg') }</style>
      """)

      File.write!(Path.join(@fixture_dir, "src/vue_css_asset.ts"), """
      import './App.vue'
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/vue_css_asset.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      css = File.read!(result.css.path)
      assert css =~ ~r/\/assets\/logo-[a-f0-9]{8}\.svg/
      refute css =~ "./logo.svg"

      assert [asset_path] = Path.wildcard(Path.join(@outdir, "logo-*.svg"))
      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert Path.basename(asset_path) in manifest["vue_css_asset.css"]["assets"]
    end

    test "dynamic CSS imports become inert browser-loadable modules" do
      File.write!(Path.join(@fixture_dir, "src/theme.css"), "body { color: red }")

      File.write!(Path.join(@fixture_dir, "src/dynamic_css_entry.ts"), """
      import('./theme.css').then(() => {
        document.body.dataset.css = 'loaded'
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

      js = File.read!(result.js.path)
      assert js =~ ~r/Promise\.resolve\(\{ default: (undefined|void 0) \}\)/
      refute js =~ "import("
      refute js =~ "data:text/css"
      refute js =~ "color: red"
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
  end
end
