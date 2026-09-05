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
