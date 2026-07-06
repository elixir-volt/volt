defmodule Volt.PreloadTest do
  use ExUnit.Case, async: true

  describe "tags/2" do
    test "generates modulepreload links from manifest map" do
      manifest = %{
        "app.js" => "app-abc123.js",
        "app-admin.js" => "app-admin-def456.js",
        "app.css" => "app-789abc.css"
      }

      result = Volt.Preload.tags(manifest, prefix: "/assets/js")

      assert result =~ ~s(rel="modulepreload")
      assert result =~ "app-abc123.js"
      assert result =~ "app-admin-def456.js"
      refute result =~ ".css"
    end

    test "preloads only static imports for a selected manifest entry" do
      manifest = %{
        "app.js" => %{
          "file" => "app-abc123.js",
          "imports" => ["common-def456.js"],
          "dynamicImports" => ["lazy-fedcba.js"]
        },
        "common-def456.js" => %{"file" => "common-def456.js", "imports" => ["vendor-111111.js"]},
        "vendor-111111.js" => %{"file" => "vendor-111111.js"},
        "lazy-fedcba.js" => %{"file" => "lazy-fedcba.js"}
      }

      result = Volt.Preload.tags(manifest, prefix: "/assets/js", entry: "app.js")

      assert result =~ "common-def456.js"
      assert result =~ "vendor-111111.js"
      refute result =~ "app-abc123.js"
      refute result =~ "lazy-fedcba.js"
    end

    test "joins prefix with URI semantics" do
      manifest = %{"app.js" => "app-abc123.js"}

      result = Volt.Preload.tags(manifest, prefix: "https://cdn.example.com/assets/js/")

      assert result =~ ~s(href="https://cdn.example.com/assets/js/app-abc123.js")
      refute result =~ "https:/cdn.example.com"
    end

    test "reads from manifest file" do
      dir = Path.join(System.tmp_dir!(), "volt-preload-test")
      File.mkdir_p!(dir)
      path = Path.join(dir, "manifest.json")
      File.write!(path, Jason.encode!(%{"app.js" => "app-abc.js"}))

      on_exit(fn -> File.rm_rf!(dir) end)

      result = Volt.Preload.tags(path)
      assert result =~ "app-abc.js"
    end

    test "escapes href attribute values" do
      manifest = %{"bad.js" => ~s|bad" onclick="alert(1).js|}

      result = Volt.Preload.tags(manifest)

      assert result =~ "&quot;"
      refute result =~ ~s(href="/assets/bad" onclick=)
    end

    test "does not recurse forever on cyclic imports" do
      manifest = %{
        "app.js" => %{"file" => "app.js", "imports" => ["a.js"]},
        "a.js" => %{"file" => "a.js", "imports" => ["b.js"]},
        "b.js" => %{"file" => "b.js", "imports" => ["a.js"]}
      }

      result = Volt.Preload.tags(manifest, entry: "app.js")

      assert result =~ "a.js"
      assert result =~ "b.js"
    end
  end
end
