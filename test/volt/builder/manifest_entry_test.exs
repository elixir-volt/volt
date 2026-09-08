defmodule Volt.Builder.ManifestEntryTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.ManifestEntry

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
