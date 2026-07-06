defmodule Volt.AssetsTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.join(System.tmp_dir!(), "volt-assets-test")

  setup do
    File.mkdir_p!(@fixture_dir)
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "asset?/1" do
    test "recognizes image types" do
      assert Volt.Assets.asset?("photo.jpg")
      assert Volt.Assets.asset?("icon.svg")
      assert Volt.Assets.asset?("logo.png")
      assert Volt.Assets.asset?("banner.webp")
      assert Volt.Assets.asset?("sound.ogg")
    end

    test "recognizes font types" do
      assert Volt.Assets.asset?("font.woff2")
      assert Volt.Assets.asset?("font.ttf")
    end

    test "rejects code files" do
      refute Volt.Assets.asset?("app.ts")
      refute Volt.Assets.asset?("style.css")
      refute Volt.Assets.asset?("App.vue")
    end
  end

  describe "resolve/2" do
    test "resolves aliases" do
      File.mkdir_p!(Path.join(@fixture_dir, "icons"))
      path = Path.join(@fixture_dir, "icons/mark.svg")
      File.write!(path, "<svg />")

      assert {:ok, ^path} =
               Volt.Assets.resolve("@/icons/mark.svg", aliases: %{"@" => @fixture_dir})
    end

    test "resolves relative specifiers from an importer" do
      File.mkdir_p!(Path.join(@fixture_dir, "pages"))
      File.mkdir_p!(Path.join(@fixture_dir, "icons"))
      importer = Path.join(@fixture_dir, "pages/index.astral")
      path = Path.join(@fixture_dir, "icons/clip-paths.svg")
      File.write!(importer, "")
      File.write!(path, "<svg />")

      assert {:ok, ^path} = Volt.Assets.resolve("../icons/clip-paths.svg", importer: importer)
    end

    test "resolves root-relative and plain root specifiers" do
      File.mkdir_p!(Path.join(@fixture_dir, "icons"))
      path = Path.join(@fixture_dir, "icons/logo.svg")
      File.write!(path, "<svg />")

      assert {:ok, ^path} = Volt.Assets.resolve("/icons/logo.svg", root: @fixture_dir)
      assert {:ok, ^path} = Volt.Assets.resolve("icons/logo.svg", root: @fixture_dir)
    end

    test "tries configured extensions" do
      File.mkdir_p!(Path.join(@fixture_dir, "icons"))
      path = Path.join(@fixture_dir, "icons/logo.svg")
      File.write!(path, "<svg />")

      assert {:ok, ^path} =
               Volt.Assets.resolve("@/icons/logo",
                 aliases: %{"@" => @fixture_dir},
                 extensions: [".svg"]
               )
    end

    test "returns not found for missing assets" do
      assert {:error, {:not_found, "missing.svg"}} =
               Volt.Assets.resolve("missing.svg", root: @fixture_dir)
    end
  end

  describe "to_js_module/2" do
    test "inlines small files as data URI" do
      path = Path.join(@fixture_dir, "tiny.svg")
      File.write!(path, "<svg/>")

      {:ok, js} = Volt.Assets.to_js_module(path, inline_limit: 4096)
      assert js =~ "data:image/svg+xml;base64,"
      assert js =~ "export default"
    end

    test "references large files by URL" do
      path = Path.join(@fixture_dir, "large.png")
      File.write!(path, String.duplicate("x", 5000))

      {:ok, js} = Volt.Assets.to_js_module(path, inline_limit: 4096)
      assert js =~ "export default"
      assert js =~ "large.png"
    end

    test "exports raw file contents" do
      path = Path.join(@fixture_dir, "raw.txt")
      File.write!(path, "hello\nworld")

      assert {:ok, ~s(export default "hello\\nworld";\n)} =
               Volt.Assets.to_js_module(path, raw: true)
    end

    test "exports forced asset URLs" do
      path = Path.join(@fixture_dir, "small.svg")
      File.write!(path, "<svg></svg>")

      assert {:ok, ~s(export default "/assets/icons/small.svg";\n)} =
               Volt.Assets.to_js_module(path, url: true, url_path: "/assets/icons/small.svg")
    end
  end

  describe "copy_hashed/2" do
    test "copies with content hash" do
      source = Path.join(@fixture_dir, "icon.svg")
      outdir = Path.join(@fixture_dir, "dist")
      File.write!(source, "<svg>test</svg>")

      {:ok, filename} = Volt.Assets.copy_hashed(source, outdir)
      assert filename =~ ~r/^icon-[a-f0-9]{8}\.svg$/
      assert File.regular?(Path.join(outdir, filename))
    end
  end

  describe "mime_type/1" do
    test "returns correct MIME types" do
      assert Volt.Assets.mime_type("file.svg") == "image/svg+xml"
      assert Volt.Assets.mime_type("file.woff2") == "font/woff2"
      assert Volt.Assets.mime_type("file.ogg") == "audio/ogg"
      assert Volt.Assets.mime_type("file.unknown") == "application/octet-stream"
    end
  end
end
