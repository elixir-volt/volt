defmodule Volt.PackageResolverTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/package_resolver", __DIR__)

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "node_modules/pkg"))
    File.mkdir_p!(Path.join(@fixture_dir, "node_modules/cjs-pkg"))

    File.write!(
      Path.join(@fixture_dir, "node_modules/pkg/package.json"),
      :json.encode(%{
        "name" => "pkg",
        "exports" => %{
          "." => %{
            "browser" => "./browser.js",
            "import" => "./module.js",
            "default" => "./default.js",
            "require" => "./require.js"
          }
        }
      })
    )

    File.write!(Path.join(@fixture_dir, "node_modules/pkg/browser.js"), "export default 'browser'")
    File.write!(Path.join(@fixture_dir, "node_modules/pkg/module.js"), "export default 'module'")
    File.write!(Path.join(@fixture_dir, "node_modules/pkg/default.js"), "export default 'default'")
    File.write!(Path.join(@fixture_dir, "node_modules/pkg/require.js"), "module.exports = 'require'")

    File.write!(
      Path.join(@fixture_dir, "node_modules/cjs-pkg/package.json"),
      :json.encode(%{"name" => "cjs-pkg", "main" => "./index.cjs"})
    )

    File.write!(Path.join(@fixture_dir, "node_modules/cjs-pkg/index.cjs"), "module.exports = { value: 1 }")

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  test "prefers browser then import exports" do
    package_dir = Path.join(@fixture_dir, "node_modules/pkg")

    assert {:ok, path} =
             Volt.PackageResolver.resolve_package_entry(package_dir, "pkg", fn base ->
               if File.regular?(base), do: {:ok, base}, else: {:error, :missing}
             end)

    assert path =~ "/browser.js"
  end

  test "resolves commonjs main files" do
    package_dir = Path.join(@fixture_dir, "node_modules/cjs-pkg")

    assert {:ok, path} =
             Volt.PackageResolver.resolve_package_entry(package_dir, "cjs-pkg", fn base ->
               if File.regular?(base), do: {:ok, base}, else: {:error, :missing}
             end)

    assert path =~ "/index.cjs"
  end
end
