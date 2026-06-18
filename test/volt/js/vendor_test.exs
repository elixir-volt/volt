defmodule Volt.JS.VendorTest do
  use ExUnit.Case, async: false

  @fixture_dir Path.expand("fixtures/vendor", __DIR__)
  @node_modules Path.join(@fixture_dir, "node_modules")
  @deps_dir Path.join(@fixture_dir, "deps")

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

    test "does not scan into node_modules under the root" do
      # A real package referenced only from *inside* node_modules.
      File.mkdir_p!(Path.join(@node_modules, "nested-only"))

      File.write!(
        Path.join(@node_modules, "nested-only/package.json"),
        :json.encode(%{"name" => "nested-only", "main" => "index.js"})
      )

      File.write!(Path.join(@node_modules, "nested-only/index.js"), "export const x = 1;")

      File.write!(
        Path.join(@node_modules, "fake-lib/extra.js"),
        "import { x } from 'nested-only'\nexport { x }\n"
      )

      # Scan the whole fixture, which contains both src/ and node_modules/.
      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(root: @fixture_dir, node_modules: @node_modules)

      # The app's own bare import is still detected...
      assert Map.has_key?(vendor_map, "fake-lib")
      # ...but an import that only appears *inside* node_modules is not, since the
      # scan must not crawl dependency trees (thousands of files in real apps).
      refute Map.has_key?(vendor_map, "nested-only")
    end

    test "optimizes multiple packages in one shared dependency graph" do
      File.mkdir_p!(Path.join(@node_modules, "editor-a"))
      File.mkdir_p!(Path.join(@node_modules, "editor-b"))
      File.mkdir_p!(Path.join(@node_modules, "singleton-state"))

      File.write!(
        Path.join(@node_modules, "editor-a/package.json"),
        ~s({"name":"editor-a","main":"index.js"})
      )

      File.write!(
        Path.join(@node_modules, "editor-b/package.json"),
        ~s({"name":"editor-b","main":"index.js"})
      )

      File.write!(
        Path.join(@node_modules, "singleton-state/package.json"),
        ~s({"name":"singleton-state","main":"index.js"})
      )

      File.write!(
        Path.join(@node_modules, "editor-a/index.js"),
        "import { state } from 'singleton-state'; export const a = state;"
      )

      File.write!(
        Path.join(@node_modules, "editor-b/index.js"),
        "import { state } from 'singleton-state'; export const b = state;"
      )

      File.write!(
        Path.join(@node_modules, "singleton-state/index.js"),
        "export const state = { singleton: true };"
      )

      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { a } from 'editor-a'; import { b } from 'editor-b'; console.log(a, b);"
      )

      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: @node_modules
        )

      assert Map.has_key?(vendor_map, "editor-a")
      assert Map.has_key?(vendor_map, "editor-b")

      {:ok, editor_a} = Volt.JS.Vendor.read("editor-a")
      {:ok, editor_b} = Volt.JS.Vendor.read("editor-b")

      assert [chunk] =
               [editor_a, editor_b]
               |> Enum.flat_map(&Regex.scan(~r{\.\/chunks\/[^"']+\.js}, &1))
               |> List.flatten()
               |> Enum.uniq()

      chunk_specifier = chunk |> String.trim_leading("./") |> String.trim_trailing(".js")
      {:ok, shared_chunk} = Volt.JS.Vendor.read(chunk_specifier)
      assert shared_chunk =~ "singleton"
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

    test "keeps previous cache files when a later optimization fails" do
      defmodule StableSyntheticVendor do
        @behaviour Volt.Plugin

        def name, do: "stable-synthetic"

        def prebundle_entry("unstable-lib"),
          do: {:source, "unstable-lib.js", "export const value = 'stable'"}

        def prebundle_entry(_specifier), do: nil
      end

      defmodule BrokenSyntheticVendor do
        @behaviour Volt.Plugin

        def name, do: "broken-synthetic"
        def prebundle_entry("unstable-lib"), do: {:source, "unstable-lib.js", "const = ;"}
        def prebundle_entry(_specifier), do: nil
      end

      {:ok, stable} =
        Volt.JS.Vendor.bundle_on_demand("unstable-lib", @node_modules,
          plugins: [StableSyntheticVendor]
        )

      assert {:error, _} =
               Volt.JS.Vendor.bundle_on_demand("unstable-lib", @node_modules,
                 plugins: [BrokenSyntheticVendor]
               )

      assert {:ok, ^stable} = Volt.JS.Vendor.read("unstable-lib")
    end

    test "rebuilds cached synthetic entries when plugin prebundle source changes" do
      defmodule SyntheticVendorOne do
        @behaviour Volt.Plugin

        def name, do: "synthetic-one"

        def prebundle_entry("synthetic-lib"),
          do: {:source, "synthetic-lib.js", "export const value = 'one'"}

        def prebundle_entry(_specifier), do: nil
      end

      defmodule SyntheticVendorTwo do
        @behaviour Volt.Plugin

        def name, do: "synthetic-two"

        def prebundle_entry("synthetic-lib"),
          do: {:source, "synthetic-lib.js", "export const value = 'two'"}

        def prebundle_entry(_specifier), do: nil
      end

      {:ok, one} =
        Volt.JS.Vendor.bundle_on_demand("synthetic-lib", @node_modules,
          plugins: [SyntheticVendorOne]
        )

      {:ok, two} =
        Volt.JS.Vendor.bundle_on_demand("synthetic-lib", @node_modules,
          plugins: [SyntheticVendorTwo]
        )

      assert one =~ "one"
      assert two =~ "two"
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
      assert code =~ "exports.b = require_dep_a().a + 1"
    end
  end

  describe "resolve_dirs" do
    setup do
      File.mkdir_p!(Path.join(@deps_dir, "hex-lib"))

      File.write!(
        Path.join(@deps_dir, "hex-lib/package.json"),
        :json.encode(%{"name" => "hex-lib", "main" => "index.js"})
      )

      File.write!(
        Path.join(@deps_dir, "hex-lib/index.js"),
        "export const value = 'from deps';"
      )

      :ok
    end

    test "prebundles packages from additional resolve directories" do
      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { value } from 'hex-lib'\nconsole.log(value)"
      )

      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: nil,
          resolve_dirs: [@deps_dir]
        )

      assert Map.has_key?(vendor_map, "hex-lib")
      {:ok, code} = Volt.JS.Vendor.read("hex-lib")
      assert code =~ "from deps"
    end

    test "bundles on demand from additional resolve directories" do
      {:ok, code} =
        Volt.JS.Vendor.bundle_on_demand("hex-lib", nil, resolve_dirs: [@deps_dir])

      assert code =~ "from deps"
    end

    test "bundles Phoenix colocated JS from additional resolve directories" do
      File.mkdir_p!(Path.join(@deps_dir, "phoenix-colocated/my_app/MyAppWeb.DemoLive"))

      File.write!(
        Path.join(@deps_dir, "phoenix-colocated/my_app/index.js"),
        """
        import hook from './MyAppWeb.DemoLive/line_42.js'
        export const hooks = {'MyAppWeb.DemoLive.Sortable': hook}
        export default {hooks}
        """
      )

      File.write!(
        Path.join(@deps_dir, "phoenix-colocated/my_app/MyAppWeb.DemoLive/line_42.js"),
        "export default {mounted() { console.log('colocated hook mounted') }};"
      )

      File.write!(
        Path.join(@fixture_dir, "src/app.ts"),
        "import { hooks } from 'phoenix-colocated/my_app'\nconsole.log(hooks)"
      )

      {:ok, vendor_map} =
        Volt.JS.Vendor.prebundle(
          root: Path.join(@fixture_dir, "src"),
          node_modules: nil,
          resolve_dirs: [@deps_dir]
        )

      assert Map.has_key?(vendor_map, "phoenix-colocated/my_app")
      {:ok, code} = Volt.JS.Vendor.read("phoenix-colocated/my_app")
      assert code =~ "MyAppWeb.DemoLive.Sortable"
      assert code =~ "colocated hook mounted"
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
    test "adds a stable browser hash when options are provided" do
      url = Volt.JS.Vendor.vendor_url("vue", node_modules: @node_modules, plugins: [])

      assert url =~ "/@vendor/vue.js?v="
      assert Volt.JS.Vendor.vendor_url("vue", node_modules: @node_modules, plugins: []) == url

      refute Volt.JS.Vendor.vendor_url("vue",
               node_modules: @node_modules,
               plugins: [Volt.Plugin.React]
             ) == url
    end

    test "browser hash changes when lockfile changes" do
      lockfile = Path.join(@fixture_dir, "package-lock.json")
      File.write!(lockfile, ~s({"lockfileVersion":1}))
      first = Volt.JS.Vendor.browser_hash(node_modules: @node_modules, plugins: [])

      File.write!(lockfile, ~s({"lockfileVersion":2}))
      second = Volt.JS.Vendor.browser_hash(node_modules: @node_modules, plugins: [])

      refute first == second
    end

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
