defmodule Volt.CSS.AssetURLRewriterTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("../fixtures/css_asset_rewriter", __DIR__)
  @outdir Path.join(@fixture_dir, "dist")

  setup do
    File.rm_rf!(@fixture_dir)
    File.mkdir_p!(Path.join(@fixture_dir, "src/icons"))
    File.mkdir_p!(@outdir)

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)

    :ok
  end

  test "rewrites relative url nodes through hashed assets" do
    File.write!(Path.join(@fixture_dir, "src/icons/logo.svg"), "<svg></svg>")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite(
        ".logo { background: url('./icons/logo.svg') }",
        source_path,
        @outdir
      )

    assert css =~ ~r/url\(['"]\/assets\/logo-[a-f0-9]{8}\.svg['"]\)/
    assert [asset] = Path.wildcard(Path.join(@outdir, "logo-*.svg"))
    assert File.read!(asset) == "<svg></svg>"
  end

  test "returns emitted asset filenames once per source asset" do
    File.write!(Path.join(@fixture_dir, "src/icons/logo.svg"), "<svg></svg>")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, result} =
      Volt.CSS.AssetURLRewriter.rewrite_with_assets(
        ".a{background:url('./icons/logo.svg')} .b{background:url('./icons/logo.svg')}",
        source_path,
        @outdir
      )

    assert result.code =~ ~r/\/assets\/logo-[a-f0-9]{8}\.svg/
    assert [%{file: "logo-" <> _, src: "logo.svg"}] = result.assets
    assert [_asset] = Path.wildcard(Path.join(@outdir, "logo-*.svg"))
  end

  test "rewrites URLs after non-ASCII content" do
    File.write!(Path.join(@fixture_dir, "src/icons/logo.svg"), "<svg></svg>")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite(
        ".title::before { content: 'Привет'; }\n.logo { background: url('./icons/logo.svg') }",
        source_path,
        @outdir
      )

    assert css =~ "Привет"
    assert css =~ ~r/\/assets\/logo-[a-f0-9]{8}\.svg/
    refute css =~ "./icons/logo.svg"
  end

  test "rewrites dev URLs without copying assets" do
    File.write!(Path.join(@fixture_dir, "src/icons/logo.svg"), "<svg></svg>")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite_dev(
        ".logo { background: url('./icons/logo.svg?v=1') }",
        source_path,
        Path.join(@fixture_dir, "src"),
        "/assets"
      )

    assert css =~ "/assets/icons/logo.svg?v=1"
    assert [] = Path.wildcard(Path.join(@outdir, "logo-*.svg"))
  end

  test "does not rewrite dev URLs outside root with sibling prefix" do
    sibling_dir = Path.join(@fixture_dir, "src-other")
    File.mkdir_p!(sibling_dir)
    File.write!(Path.join(sibling_dir, "logo.svg"), "<svg></svg>")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite_dev(
        ".logo { background: url('../src-other/logo.svg') }",
        source_path,
        Path.join(@fixture_dir, "src"),
        "/assets"
      )

    assert css =~ "../src-other/logo.svg"
    refute css =~ "/assets/../src-other/logo.svg"
  end

  test "rewrites image-set url nodes and preserves query and fragment suffixes" do
    File.write!(Path.join(@fixture_dir, "src/one.png"), "one")
    File.write!(Path.join(@fixture_dir, "src/two.png"), "two")
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite(
        ".hero { background-image: image-set(url('./one.png?v=1#x') 1x, url('./two.png') 2x) }",
        source_path,
        @outdir
      )

    assert css =~ ~r/\/assets\/one-[a-f0-9]{8}\.png\?v=1#x/
    assert css =~ ~r/\/assets\/two-[a-f0-9]{8}\.png/
  end

  test "rewrites Monaco-style CSS without AST print roundtrip" do
    File.write!(Path.join(@fixture_dir, "src/codicon.ttf"), "font")
    source_path = Path.join(@fixture_dir, "src/editor.main.css")

    css =
      ".x{left:calc(var(--vscode-sash-size)*-.5)}" <>
        "@font-face{src:url(codicon.ttf)}"

    {:ok, result} = Volt.CSS.AssetURLRewriter.rewrite_with_assets(css, source_path, @outdir)

    assert result.code =~ "calc(var(--vscode-sash-size)*-.5)"
    assert result.code =~ ~r/\/assets\/codicon-[a-f0-9]{8}\.ttf/
    assert [%{src: "codicon.ttf"}] = result.assets
  end

  test "leaves external, absolute, data, and unknown URLs unchanged" do
    source_path = Path.join(@fixture_dir, "src/app.css")

    {:ok, css} =
      Volt.CSS.AssetURLRewriter.rewrite(
        ".a{background:url('https://example.com/a.png')} .b{background:url('/logo.svg')} .c{background:url('data:image/svg+xml;base64,abc')} .d{background:url('./missing.svg')}",
        source_path,
        @outdir
      )

    assert css =~ "https://example.com/a.png"
    assert css =~ "/logo.svg"
    assert css =~ "data:image/svg+xml;base64,abc"
    assert css =~ "./missing.svg"
  end
end
