defmodule Volt.Tailwind.BuildTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  test "nested stylesheet assets retain their origins", %{tmp_dir: root} do
    for directory <- ["a", "b"] do
      File.mkdir_p!(Path.join(root, directory))
      File.write!(Path.join([root, directory, "logo.svg"]), "<svg>#{directory}</svg>")

      File.write!(
        Path.join([root, directory, "theme.css"]),
        ".#{directory} { background: url('./logo.svg?v=1#mark') }"
      )
    end

    File.write!(Path.join(root, "a/font.woff2"), <<0, 1, 2, 3>>)

    File.write!(
      Path.join(root, "a/font.css"),
      "@font-face { font-family: Test; src: url('./font.woff2') }"
    )

    css = Path.join(root, "style.css")

    File.write!(
      css,
      "@import 'tailwindcss' source(none); @import './a/theme.css'; @import './b/theme.css'; @import './a/font.css';"
    )

    config = Volt.Config.Tailwind.new(css: css)

    assert {:ok, result, plan} =
             Volt.Tailwind.Build.prepare(config,
               outdir: Path.join(root, "output"),
               root: root,
               hash: false,
               minify: false,
               asset_url_prefix: "https://cdn.example/assets"
             )

    code = Enum.find(plan.artifacts, &(&1.file == "style.css")).content

    for source <- ["a/logo.svg", "b/logo.svg", "a/font.woff2"] do
      file = Map.fetch!(result.manifest, source).file
      assert code =~ "https://cdn.example/assets/#{file}"
      assert Enum.any?(plan.artifacts, &(&1.file == file))
    end

    refute result.manifest["a/logo.svg"].file == result.manifest["b/logo.svg"].file
    assert code =~ "?v=1#mark"
  end

  test "compiler sources and exclusions control production scanning", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "pages"))
    File.write!(Path.join(root, "pages/index.html"), ~s(<div class="flex"></div>))
    File.write!(Path.join(root, "pages/private.html"), ~s(<div class="hidden"></div>))
    File.write!(Path.join(root, "outside.html"), ~s(<div class="grid"></div>))
    css = Path.join(root, "style.css")

    File.write!(
      css,
      "@import 'tailwindcss' source(none); @source './pages/*.html'; @source not './pages/private.html';"
    )

    config = Volt.Config.Tailwind.new(css: css)
    opts = [outdir: Path.join(root, "output"), root: root, hash: false, minify: false]
    assert {:ok, _, plan} = Volt.Tailwind.Build.prepare(config, opts)
    code = Enum.find(plan.artifacts, &(&1.file == "style.css")).content
    assert code =~ ".flex"
    refute code =~ ".hidden"
    refute code =~ ".grid"

    File.write!(css, "@import 'tailwindcss';")
    assert {:ok, _, automatic} = Volt.Tailwind.Build.prepare(config, opts)
    code = Enum.find(automatic.artifacts, &(&1.file == "style.css")).content
    assert code =~ ".grid"
  end

  test "production preparations scan fresh without registering workers", %{tmp_dir: root} do
    css = Path.join(root, "style.css")
    page = Path.join(root, "page.html")
    File.write!(css, "@import 'tailwindcss' source(none);")
    File.write!(page, ~s(<div class="hidden flex"></div>))
    config = Volt.Config.Tailwind.new(css: css, sources: [%{base: root, pattern: "*.html"}])
    opts = [outdir: Path.join(root, "output"), hash: false, minify: false]
    workers = Registry.count(Volt.Tailwind.Registry)

    assert {:ok, _, first} = Volt.Tailwind.Build.prepare(config, opts)
    assert Enum.any?(first.artifacts, &String.contains?(&1.content, ".hidden"))
    File.write!(page, ~s(<div class="flex"></div>))
    assert {:ok, _, second} = Volt.Tailwind.Build.prepare(config, opts)
    refute Enum.any?(second.artifacts, &String.contains?(&1.content, ".hidden"))
    assert Registry.count(Volt.Tailwind.Registry) == workers
  end

  test "prepares CSS and referenced assets without creating output", %{tmp_dir: root} do
    css = Path.join(root, "style.css")

    File.write!(
      css,
      "@import 'tailwindcss' source(none); .logo { background: url('./logo.svg') }"
    )

    File.write!(Path.join(root, "logo.svg"), "<svg/>")
    output = Path.join(root, "output")
    config = Volt.Config.Tailwind.new(css: css, name: "site")

    assert {:ok, result, plan} =
             Volt.Tailwind.Build.prepare(config,
               key: {:preparation_test, root},
               outdir: output,
               root: root,
               hash: false,
               minify: false,
               asset_url_prefix: "/static"
             )

    assert result.manifest["site.css"].file == "site.css"
    assert Enum.any?(plan.artifacts, &(&1.file == "site.css"))
    assert Enum.any?(plan.artifacts, &(&1.content == "<svg/>"))
    refute File.exists?(output)
  end
end
