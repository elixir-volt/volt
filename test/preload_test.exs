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

    test "reads from manifest file" do
      dir = Path.expand("fixtures/preload", __DIR__)
      File.mkdir_p!(dir)
      path = Path.join(dir, "manifest.json")
      File.write!(path, :json.encode(%{"app.js" => "app-abc.js"}))

      on_exit(fn -> File.rm_rf!(dir) end)

      result = Volt.Preload.tags(path)
      assert result =~ "app-abc.js"
    end
  end
end
