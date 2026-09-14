defmodule Volt.Builder.ManifestEntryTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.ManifestEntry

  test "stylesheet traversal is dependency-first, deduplicated, and cycle-safe" do
    manifest = %{
      "app" => %ManifestEntry{imports: ["a", "b"], css: ["app.css"], dynamicImports: ["lazy"]},
      "a" => %ManifestEntry{imports: ["b"], css: ["a.css"]},
      "b" => %ManifestEntry{imports: ["a"], css: ["shared.css", "a.css"]},
      "lazy" => %ManifestEntry{css: ["lazy.css"]}
    }

    assert ManifestEntry.stylesheets(manifest, "app") == ["shared.css", "a.css", "app.css"]
  end

  test "output prefixes do not alter manifest references or source identity" do
    entry = %ManifestEntry{
      src: "src/app.ts",
      file: "app-hash.js",
      imports: ["shared"],
      dynamicImports: ["lazy"],
      css: ["app-hash.css"],
      assets: ["logo-hash.svg"]
    }

    assert ManifestEntry.prefix_paths(entry, "js") == %ManifestEntry{
             src: "src/app.ts",
             file: "js/app-hash.js",
             imports: ["shared"],
             dynamicImports: ["lazy"],
             css: ["js/app-hash.css"],
             assets: ["js/logo-hash.svg"]
           }
  end
end
