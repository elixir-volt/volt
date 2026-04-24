defmodule VoltTest do
  use ExUnit.Case, async: true
  doctest Volt

  defmodule DevEndpoint do
    def config(:code_reloader), do: true
  end

  defmodule ProdEndpoint do
    def config(:code_reloader), do: false
  end

  test "entry_path points at source entry in development" do
    assert Volt.entry_path(DevEndpoint,
             entry: "assets/js/app.tsx",
             root: "assets",
             prefix: "/assets"
           ) == "/assets/js/app.tsx"
  end

  test "entry_path reads production manifest" do
    outdir = tmp_dir("manifest")
    File.mkdir_p!(outdir)
    File.write!(Path.join(outdir, "manifest.json"), ~s({"app.js":{"file":"app-deadbeef.js"}}))

    assert Volt.entry_path(ProdEndpoint,
             entry: "assets/js/app.ts",
             outdir: outdir,
             prefix: "/assets"
           ) == "/assets/app-deadbeef.js"
  end

  defp tmp_dir(name) do
    Path.join([System.tmp_dir!(), "volt-test-#{System.unique_integer([:positive])}", name])
  end
end
