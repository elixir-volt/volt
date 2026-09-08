defmodule Volt.BuildTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    root = Path.join(tmp, "assets")
    outdir = Path.join(tmp, "dist/assets")
    File.mkdir_p!(root)
    File.write!(Path.join(root, "app.ts"), "document.body.dataset.ready = 'true'")
    File.write!(Path.join(root, "styles.css"), ~S|@import "tailwindcss" source(none);|)
    File.write!(Path.join(root, "page.html"), ~S|<main class="grid gap-4"></main>|)

    {:ok, root: root, outdir: outdir}
  end

  test "nested assets keep public files and manifest at the publication root", %{
    root: root,
    outdir: outdir
  } do
    public = Path.join(root, "public")
    File.mkdir_p!(public)
    File.write!(Path.join(public, "robots.txt"), "public")

    for layout <- [:flat, :split] do
      destination = Path.join(outdir, Atom.to_string(layout))

      assert {:ok, result} =
               Volt.build(
                 entry: Path.join(root, "app.ts"),
                 root: root,
                 outdir: destination,
                 assets_dir: "assets",
                 output_layout: layout,
                 public_dir: public,
                 tailwind: [],
                 hash: false
               )

      suffix = if layout == :flat, do: "assets/app.js", else: "assets/js/app.js"
      assert result.manifest["app.js"].file == suffix
      assert File.regular?(Path.join(destination, suffix))
      assert File.regular?(Path.join(destination, "manifest.json"))
      assert File.read!(Path.join(destination, "robots.txt")) == "public"
    end
  end

  test "public destination is independent of asset layout", %{root: root, outdir: outdir} do
    public = Path.join(root, "public")
    File.mkdir_p!(public)
    File.write!(Path.join(public, "robots.txt"), "public")

    for layout <- [:flat, :split] do
      destination = Path.join(outdir, Atom.to_string(layout))

      assert {:ok, _} =
               Volt.build(
                 entry: Path.join(root, "app.ts"),
                 root: root,
                 outdir: destination,
                 output_layout: layout,
                 public_dir: public,
                 tailwind: []
               )

      assert File.read!(Path.join(destination, "robots.txt")) == "public"
    end
  end

  test "returns every standalone stylesheet", %{root: root, outdir: outdir} do
    entries =
      for name <- ["first", "second"] do
        path = Path.join(root, "#{name}.css")
        File.write!(path, ".#{name} { color: red }")
        path
      end

    assert {:ok, result} =
             Volt.build(entry: entries, root: root, outdir: outdir, tailwind: [], hash: false)

    assert Enum.map(result.styles, &Path.basename(&1.path)) == ["first.css", "second.css"]
    assert result.assets.styles == result.styles
    assert Enum.all?(result.styles, &File.regular?(&1.path))
  end

  test "flat output deduplicates assets shared by Tailwind and JavaScript", %{
    root: root,
    outdir: outdir
  } do
    File.write!(Path.join(root, "logo.svg"), "<svg/>")
    File.write!(Path.join(root, "app.ts"), "import logo from './logo.svg?url'; console.log(logo)")

    File.write!(
      Path.join(root, "styles.css"),
      "@import 'tailwindcss' source(none); .logo { background: url('./logo.svg') }"
    )

    assert {:ok, result} =
             Volt.build(
               entry: Path.join(root, "app.ts"),
               root: root,
               outdir: outdir,
               output_layout: :flat,
               hash: false,
               minify: false,
               tailwind: [css: Path.join(root, "styles.css")]
             )

    assert %Volt.Builder.ManifestEntry{file: file} = result.manifest["logo.svg"]
    assert File.read!(Path.join(outdir, file)) == "<svg/>"
    assert [_] = Path.wildcard(Path.join(outdir, "logo-*.svg"))
  end

  test "public files cannot overwrite compiled output", %{root: root, outdir: outdir} do
    public = Path.join(root, "public")
    File.mkdir_p!(Path.join(public, "js"))
    File.write!(Path.join(public, "js/app.js"), "public collision")

    opts = [
      entry: Path.join(root, "app.ts"),
      root: root,
      outdir: outdir,
      hash: false,
      minify: false,
      sourcemap: false,
      tailwind: []
    ]

    assert {:ok, _} = Volt.build(opts)
    previous = File.read!(Path.join(outdir, "js/app.js"))

    assert {:error, {:output_collision, "js/app.js"}} =
             Volt.build(Keyword.put(opts, :public_dir, public))

    assert File.read!(Path.join(outdir, "js/app.js")) == previous
  end

  test "later entry failure leaves the previous build untouched", %{root: root, outdir: outdir} do
    opts = [
      root: root,
      outdir: outdir,
      hash: false,
      minify: false,
      sourcemap: false,
      tailwind: []
    ]

    entry = Path.join(root, "app.ts")
    assert {:ok, _} = Volt.build([entry: entry] ++ opts)

    snapshot = fn ->
      Path.wildcard(Path.join(outdir, "**/*"))
      |> Enum.filter(&File.regular?/1)
      |> Map.new(&{&1, File.read!(&1)})
    end

    before = snapshot.()
    File.write!(entry, "console.log('replacement')")
    bad = Path.join(root, "broken.ts")
    File.write!(bad, "export const = ;")
    assert {:error, _} = Volt.build([entry: [entry, bad]] ++ opts)
    assert snapshot.() == before
  end

  test "flat Tailwind collision preserves previous output", %{root: root, outdir: outdir} do
    plain = Path.join(root, "plain.css")
    File.write!(plain, "body { color: red }")

    opts = [
      entry: plain,
      root: root,
      outdir: outdir,
      output_layout: :flat,
      hash: false,
      tailwind: []
    ]

    assert {:ok, _} = Volt.build(opts)
    before = File.read!(Path.join(outdir, "plain.css"))
    manifest = File.read!(Path.join(outdir, "manifest.json"))

    assert {:error, {:output_collision, "plain.css"}} =
             Volt.build(
               Keyword.put(opts, :tailwind, css: Path.join(root, "styles.css"), name: "plain")
             )

    assert File.read!(Path.join(outdir, "plain.css")) == before
    assert File.read!(Path.join(outdir, "manifest.json")) == manifest
  end

  test "builds scripts and Tailwind into one manifest", %{root: root, outdir: outdir} do
    assert {:ok, result} =
             Volt.build(
               entry: Path.join(root, "app.ts"),
               root: root,
               outdir: outdir,
               hash: false,
               minify: false,
               sourcemap: false,
               tailwind: [
                 css: Path.join(root, "styles.css"),
                 name: "site",
                 sources: [%{base: root, pattern: "**/*.html"}]
               ]
             )

    assert File.regular?(Path.join(outdir, "js/app.js"))
    assert File.regular?(Path.join(outdir, "css/site.css"))
    assert File.read!(Path.join(outdir, "css/site.css")) =~ ".grid"

    assert [%Volt.Builder.OutputFile{path: style_path}] = result.styles
    assert style_path == Path.join(outdir, "css/site.css")
    assert result.assets.manifest["app.js"].file == "js/app.js"
    assert result.manifest["site.css"].file == "css/site.css"

    assert Enum.all?(result.manifest, fn {_key, entry} ->
             match?(%Volt.Builder.ManifestEntry{}, entry)
           end)

    manifest = outdir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    assert manifest["app.js"]["file"] == "js/app.js"
    assert manifest["site.css"]["file"] == "css/site.css"
    refute File.exists?(Path.join(outdir, "js/manifest.json"))
    refute File.exists?(Path.join(outdir, "css/manifest.json"))
  end

  test "shared chunk references resolve through the manifest in both layouts", %{
    root: root,
    outdir: outdir
  } do
    File.write!(
      Path.join(root, "shared.ts"),
      "export const shared = () => console.log('shared');"
    )

    entries =
      for name <- ["one", "two"] do
        path = Path.join(root, "#{name}.ts")
        File.write!(path, "import {shared} from './shared'; shared();")
        path
      end

    for layout <- [:flat, :split], hash <- [false, true] do
      output = Path.join(outdir, "#{layout}-#{hash}")

      assert {:ok, result} =
               Volt.build(
                 entry: entries,
                 root: root,
                 outdir: output,
                 output_layout: layout,
                 hash: hash,
                 format: :esm,
                 code_splitting: true,
                 minify: false,
                 sourcemap: false,
                 tailwind: []
               )

      assert [reference] = result.manifest["one.js"].imports
      assert result.manifest["two.js"].imports == [reference]
      assert %Volt.Builder.ManifestEntry{file: file} = result.manifest[reference]
      assert File.regular?(Path.join(output, file))

      assert Volt.Preload.tags(Path.join(output, "manifest.json"), entry: "one.js") ==
               ~s(<link rel="modulepreload" href="/assets/#{file}">)
    end
  end

  test "flat output resolves every emitted manifest path", %{root: root, outdir: outdir} do
    assert {:ok, result} =
             Volt.build(
               entry: Path.join(root, "app.ts"),
               root: root,
               outdir: outdir,
               output_layout: :flat,
               hash: false,
               minify: false,
               sourcemap: false,
               tailwind: [
                 css: Path.join(root, "styles.css"),
                 sources: [%{base: root, pattern: "**/*.html"}]
               ]
             )

    assert result.manifest["app.js"].file == "app.js"
    assert result.manifest["styles.css"].file == "styles.css"

    for {_key, %Volt.Builder.ManifestEntry{file: file}} <- result.manifest do
      assert File.regular?(Path.join(outdir, file))
    end

    refute File.dir?(Path.join(outdir, "js"))
    refute File.dir?(Path.join(outdir, "css"))
  end

  test "rejects colliding manifest identities", %{root: root, outdir: outdir} do
    plain_css = Path.join(root, "plain.css")
    File.write!(plain_css, "body { color: red }")

    assert {:error, {:manifest_collision, ["plain.css"]}} =
             Volt.build(
               entry: plain_css,
               root: root,
               outdir: outdir,
               hash: true,
               tailwind: [css: Path.join(root, "styles.css"), name: "plain"]
             )

    refute File.exists?(Path.join(outdir, "manifest.json"))
  end

  test "builds assets without Tailwind", %{root: root, outdir: outdir} do
    assert {:ok, result} =
             Volt.build(
               entry: Path.join(root, "app.ts"),
               root: root,
               outdir: outdir,
               hash: false,
               minify: false,
               sourcemap: false,
               tailwind: []
             )

    assert result.styles == []
    assert result.assets.css == nil
    assert File.regular?(Path.join(outdir, "js/app.js"))
    refute File.exists?(Path.join(outdir, "css/site.css"))
  end
end
