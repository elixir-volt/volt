defmodule Volt.JS.PackageResolverTest do
  use ExUnit.Case, async: true

  test "resolves package imports and extensionless CommonJS requires" do
    root =
      Path.join(
        System.tmp_dir!(),
        "volt-package-resolver-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.rm_rf!(root)
    package_dir = Path.join([root, "node_modules", "pkg"])
    File.mkdir_p!(Path.join(package_dir, "src"))
    File.mkdir_p!(Path.join(package_dir, "lib"))

    File.write!(
      Path.join(package_dir, "package.json"),
      Jason.encode!(%{
        "name" => "pkg",
        "exports" => %{
          "." => %{"import" => "./src/index.js", "default" => "./lib/index.js"},
          "./feature/*" => "./src/features/*.js"
        },
        "imports" => %{
          "#internal" => "./src/internal.js"
        }
      })
    )

    File.write!(Path.join(package_dir, "src/index.js"), "export default 1")
    File.write!(Path.join(package_dir, "src/internal.js"), "export default 2")
    File.mkdir_p!(Path.join(package_dir, "src/features"))
    File.write!(Path.join(package_dir, "src/features/a.js"), "export default 3")
    File.write!(Path.join(package_dir, "lib/helper.js"), "module.exports = 4")

    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, Path.join(package_dir, "src/index.js")} ==
             Volt.JS.PackageResolver.resolve("pkg", root)

    assert {:ok, Path.join(package_dir, "src/features/a.js")} ==
             Volt.JS.PackageResolver.resolve("pkg/feature/a", root)

    assert {:ok, Path.join(package_dir, "src/internal.js")} ==
             Volt.JS.PackageResolver.resolve("#internal", Path.join(package_dir, "src"))

    assert {:ok, Path.join(package_dir, "lib/helper.js")} ==
             Volt.JS.PackageResolver.resolve("./helper", Path.join(package_dir, "lib"))
  end
end
