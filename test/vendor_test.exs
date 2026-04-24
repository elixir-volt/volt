defmodule Volt.JS.VendorTest do
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

    File.rm_rf!("_build/volt/vendor")

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "prebundle/1" do
    test "detects bare imports and bundles them" do
      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      assert Map.has_key?(vendor_map, "fake-lib")
    end

    test "caches bundled files on disk" do
      Volt.JS.Vendor.prebundle(
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
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      refute Map.has_key?(vendor_map, "./app")
    end

    test "outputs valid ESM (export, no module.exports)" do
      Volt.JS.Vendor.prebundle(
        root: Path.join(@fixture_dir, "src"),
        node_modules: @node_modules
      )

      {:ok, code} = Volt.JS.Vendor.read("fake-lib")
      assert code =~ "greet"
      refute code =~ "module.exports"
    end
  end

  describe "CJS package bundling" do
    setup do
      File.mkdir_p!(Path.join(@node_modules, "cjs-lib"))

      File.write!(
        Path.join(@node_modules, "cjs-lib/package.json"),
        :json.encode(%{"name" => "cjs-lib", "main" => "index.js"})
      )

      File.write!(
        Path.join(@node_modules, "cjs-lib/index.js"),
        """
        'use strict';
        var helper = require('./helper');
        exports.value = helper.compute(42);
        exports.name = 'cjs-lib';
        """
      )

      File.write!(
        Path.join(@node_modules, "cjs-lib/helper.js"),
        """
        'use strict';
        exports.compute = function(x) { return x * 2; };
        """
      )

      File.write!(
        Path.join(@fixture_dir, "src/use-cjs.ts"),
        "import { value } from 'cjs-lib'\nconsole.log(value)"
      )

      :ok
    end

    test "converts CJS require/exports to valid ESM" do
      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      assert Map.has_key?(vendor_map, "cjs-lib")

      {:ok, code} = Volt.JS.Vendor.read("cjs-lib")
      assert code =~ "export"
      refute String.starts_with?(code, "\"use strict\";(function()")
    end

    test "resolves conditional CJS branches via process.env.NODE_ENV" do
      File.mkdir_p!(Path.join(@node_modules, "conditional-lib/cjs"))

      File.write!(
        Path.join(@node_modules, "conditional-lib/package.json"),
        :json.encode(%{"name" => "conditional-lib", "main" => "index.js"})
      )

      File.write!(
        Path.join(@node_modules, "conditional-lib/index.js"),
        """
        'use strict';
        if (process.env.NODE_ENV === 'production') {
          module.exports = require('./cjs/prod.js');
        } else {
          module.exports = require('./cjs/dev.js');
        }
        """
      )

      File.write!(
        Path.join(@node_modules, "conditional-lib/cjs/prod.js"),
        "'use strict';\nexports.mode = 'production';\n"
      )

      File.write!(
        Path.join(@node_modules, "conditional-lib/cjs/dev.js"),
        "'use strict';\nexports.mode = 'development';\n"
      )

      File.write!(
        Path.join(@fixture_dir, "src/use-conditional.ts"),
        "import { mode } from 'conditional-lib'\nconsole.log(mode)"
      )

      {:ok, _} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      {:ok, code} = Volt.JS.Vendor.read("conditional-lib")
      assert code =~ "development"
    end

    test "bundles cross-package CommonJS dependencies through OXC" do
      File.mkdir_p!(Path.join(@node_modules, "dep-a"))
      File.mkdir_p!(Path.join(@node_modules, "dep-b"))

      File.write!(
        Path.join(@node_modules, "dep-a/package.json"),
        :json.encode(%{"name" => "dep-a", "main" => "index.js"})
      )

      File.write!(
        Path.join(@node_modules, "dep-a/index.js"),
        "'use strict';\nexports.a = 1;\n"
      )

      File.write!(
        Path.join(@node_modules, "dep-b/package.json"),
        :json.encode(%{"name" => "dep-b", "main" => "index.js"})
      )

      File.write!(
        Path.join(@node_modules, "dep-b/index.js"),
        """
        'use strict';
        var a = require('dep-a');
        exports.b = a.a + 1;
        """
      )

      File.write!(
        Path.join(@fixture_dir, "src/use-cross-dep.ts"),
        "import { b } from 'dep-b'\nconsole.log(b)"
      )

      {:ok, _} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      {:ok, code} = Volt.JS.Vendor.read("dep-b")
      assert code =~ "require_dep_a"
      assert code =~ "exports.b = a.a + 1"
    end
  end

  describe "bundle_on_demand/2" do
    test "bundles a specifier not caught by prebundle" do
      {:ok, code} = Volt.JS.Vendor.bundle_on_demand("fake-lib", @node_modules)
      assert code =~ "greet"
    end

    test "caches the result for subsequent read/1 calls" do
      {:ok, _} = Volt.JS.Vendor.bundle_on_demand("fake-lib", @node_modules)
      {:ok, code} = Volt.JS.Vendor.read("fake-lib")
      assert code =~ "greet"
    end

    test "returns error for unknown specifier" do
      assert {:error, _} = Volt.JS.Vendor.bundle_on_demand("nonexistent", @node_modules)
    end

    test "outputs ESM for CJS packages" do
      File.mkdir_p!(Path.join(@node_modules, "on-demand-cjs"))

      File.write!(
        Path.join(@node_modules, "on-demand-cjs/package.json"),
        :json.encode(%{"name" => "on-demand-cjs", "main" => "index.js"})
      )

      File.write!(
        Path.join(@node_modules, "on-demand-cjs/index.js"),
        "'use strict';\nexports.hello = 'world';\n"
      )

      {:ok, code} = Volt.JS.Vendor.bundle_on_demand("on-demand-cjs", @node_modules)
      assert code =~ "export"
      assert code =~ "hello"
    end
  end

  describe "read/1" do
    test "reads pre-bundled vendor file" do
      Volt.JS.Vendor.prebundle(
        root: Path.join(@fixture_dir, "src"),
        node_modules: @node_modules
      )

      {:ok, code} = Volt.JS.Vendor.read("fake-lib")
      assert code =~ "greet"
    end

    test "returns error for missing vendor" do
      assert {:error, :not_found} = Volt.JS.Vendor.read("nonexistent")
    end
  end

  describe "vendor_url/1" do
    test "generates URL path for specifier" do
      assert Volt.JS.Vendor.vendor_url("vue") == "/@vendor/vue.js"
    end

    test "handles scoped packages" do
      url = Volt.JS.Vendor.vendor_url("@vue/reactivity")
      assert url =~ "/@vendor/"
      assert url =~ ".js"

      decoded =
        url
        |> String.trim_leading("/@vendor/")
        |> String.trim_trailing(".js")
        |> Volt.JS.Vendor.decode_specifier()

      assert decoded == "@vue/reactivity"
    end
  end
end
