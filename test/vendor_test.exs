defmodule Volt.VendorTest do
  use ExUnit.Case, async: false

  @fixture_dir Path.expand("fixtures/vendor", __DIR__)
  @node_modules Path.join(@fixture_dir, "node_modules")

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "src"))
    File.mkdir_p!(Path.join(@node_modules, "fake-lib"))

    File.write!(
      Path.join(@node_modules, "fake-lib/package.json"),
      :json.encode(%{"name" => "fake-lib", "main" => "index.js"})
    )

    File.write!(
      Path.join(@node_modules, "fake-lib/index.js"),
      "export const greet = (name) => `Hello, ${name}!`;"
    )

    File.write!(
      Path.join(@fixture_dir, "src/app.ts"),
      "import { greet } from 'fake-lib'\nconsole.log(greet('world'))"
    )

    # Clean vendor cache
    File.rm_rf!("_build/volt/vendor")

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "prebundle/1" do
    test "detects bare imports and bundles them" do
      {:ok, vendor_map} =
        Volt.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      assert Map.has_key?(vendor_map, "fake-lib")
    end

    test "caches bundled files on disk" do
      Volt.Vendor.prebundle(
        root: Path.join(@fixture_dir, "src"),
        node_modules: @node_modules
      )

      assert File.regular?("_build/volt/vendor/fake-lib.js")
    end

    test "skips relative imports" do
      File.write!(
        Path.join(@fixture_dir, "src/local.ts"),
        "import { foo } from './app'"
      )

      {:ok, vendor_map} =
        Volt.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      refute Map.has_key?(vendor_map, "./app")
    end
  end

  describe "read/1" do
    test "reads pre-bundled vendor file" do
      Volt.Vendor.prebundle(
        root: Path.join(@fixture_dir, "src"),
        node_modules: @node_modules
      )

      {:ok, code} = Volt.Vendor.read("fake-lib")
      assert code =~ "greet"
    end

    test "returns error for missing vendor" do
      assert {:error, :not_found} = Volt.Vendor.read("nonexistent")
    end
  end

  describe "vendor_url/1" do
    test "generates URL path for specifier" do
      assert Volt.Vendor.vendor_url("vue") == "/@vendor/vue.js"
    end

    test "handles scoped packages" do
      assert Volt.Vendor.vendor_url("@vue/reactivity") == "/@vendor/_vue_reactivity.js"
    end
  end
end
