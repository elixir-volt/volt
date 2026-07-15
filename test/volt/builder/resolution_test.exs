defmodule Volt.Builder.ResolutionTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 resolution and CommonJS" do
    test "same-name files in different directories get unique labels" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/a"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/b"))

      File.write!(Path.join(@fixture_dir, "src/a/index.js"), "export const a = 1;")
      File.write!(Path.join(@fixture_dir, "src/b/index.js"), "export const b = 2;")

      File.write!(Path.join(@fixture_dir, "src/dup_app.ts"), """
      import { a } from './a/index.js'
      import { b } from './b/index.js'
      console.log(a, b)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dup_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "1"
      assert js =~ "2"
    end

    test "shared dependencies imported by multiple modules are not duplicated" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/shared-lib"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/lib-a"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/lib-b"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/shared-lib/package.json"),
        ~s({"name":"shared-lib","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/shared-lib/index.js"),
        "export const shared = 'shared-value';\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-a/package.json"),
        ~s({"name":"lib-a","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-a/index.js"),
        "import { shared } from 'shared-lib';\nexport const a = 'a-' + shared;\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-b/package.json"),
        ~s({"name":"lib-b","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/lib-b/index.js"),
        "import { shared } from 'shared-lib';\nexport const b = 'b-' + shared;\n"
      )

      File.write!(Path.join(@fixture_dir, "src/shared_app.ts"), """
      import { a } from 'lib-a'
      import { b } from 'lib-b'
      console.log(a, b)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/shared_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "shared-value"
      assert js =~ "a-"
      assert js =~ "b-"
    end

    test "resolves bare imports from the importer's scoped package directory" do
      app_packages = Path.join(@fixture_dir, "node_modules")
      framework_root = Path.join(@fixture_dir, "framework")
      framework_packages = Path.join(framework_root, "node_modules")

      for {package_dir, value} <- [
            {Path.join(app_packages, "shared-pkg"), "app-package"},
            {Path.join(framework_packages, "shared-pkg"), "framework-package"}
          ] do
        File.mkdir_p!(package_dir)
        File.write!(Path.join(package_dir, "package.json"), ~s({"main":"index.js"}))
        File.write!(Path.join(package_dir, "index.js"), "export default #{inspect(value)};")
      end

      framework_dep = Path.join(framework_packages, "framework-dep")
      File.mkdir_p!(framework_dep)
      File.write!(Path.join(framework_dep, "package.json"), ~s({"main":"index.js"}))
      File.write!(Path.join(framework_dep, "index.js"), "export default 'scoped-transitive';")

      File.write!(Path.join(framework_packages, "shared-pkg/index.js"), """
      import dep from 'framework-dep'
      export default 'framework-package-' + dep
      """)

      File.mkdir_p!(framework_root)

      File.write!(Path.join(framework_root, "runtime.js"), """
      import value from 'shared-pkg'
      export const frameworkValue = value
      """)

      File.write!(Path.join(@fixture_dir, "src/scoped_packages_app.js"), """
      import appValue from 'shared-pkg'
      import { frameworkValue } from '../framework/runtime.js'
      console.log(appValue, frameworkValue)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/scoped_packages_app.js"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: app_packages,
          package_scopes: [{framework_root, framework_packages}]
        )

      js = File.read!(result.js.path)
      assert js =~ "app-package"
      assert js =~ "framework-package"
      assert js =~ "scoped-transitive"
    end

    test "resolves package imports from nearest package imports map" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/pkg/src/internal"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/pkg/package.json"),
        Jason.encode!(%{
          "name" => "pkg",
          "type" => "module",
          "exports" => %{"." => "./src/index.js"},
          "imports" => %{"#internal/value" => "./src/internal/value.js"}
        })
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/pkg/src/internal/value.js"),
        "export const value = 'package-import';\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/pkg/src/index.js"),
        "import { value } from '#internal/value';\nexport { value };\n"
      )

      File.write!(
        Path.join(@fixture_dir, "src/package_import_app.ts"),
        "import { value } from 'pkg';\nconsole.log(value);\n"
      )

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/package_import_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      assert File.read!(result.js.path) =~ "package-import"
    end

    test "loaders option enables JSX in .js files" do
      File.write!(Path.join(@fixture_dir, "src/jsx_app.js"), """
      const App = () => <div>Hello</div>
      export default App
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/jsx_app.js"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          loaders: %{".js" => "jsx"}
        )

      js = File.read!(result.js.path)
      assert js =~ "Hello"
    end

    test "collects CJS require() as imports" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/cjs-dep"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/cjs-dep/package.json"),
        ~s({"name":"cjs-dep","main":"index.js"})
      )

      File.write!(Path.join(@fixture_dir, "node_modules/cjs-dep/index.js"), """
      var helper = require('./helper')
      module.exports = helper
      """)

      File.write!(Path.join(@fixture_dir, "node_modules/cjs-dep/helper.js"), """
      module.exports = { value: 'cjs-works' }
      """)

      File.write!(Path.join(@fixture_dir, "src/cjs_app.ts"), """
      import dep from 'cjs-dep'
      console.log(dep.value)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/cjs_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "cjs-works"
    end

    test "rewrites bare CJS require() to the bundled module (no runtime require leak)" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/bare-cjs-dep"))
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/cjs-consumer"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/bare-cjs-dep/package.json"),
        ~s({"name":"bare-cjs-dep","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/bare-cjs-dep/index.js"),
        "module.exports = { token: 'bundled-bare-cjs' }\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/cjs-consumer/package.json"),
        ~s({"name":"cjs-consumer","main":"index.js"})
      )

      # A CJS module that requires another package by bare name — mirrors
      # react-dom's internal `require("scheduler")`.
      File.write!(Path.join(@fixture_dir, "node_modules/cjs-consumer/index.js"), """
      var dep = require('bare-cjs-dep')
      module.exports = dep.token
      """)

      File.write!(Path.join(@fixture_dir, "src/bare_cjs_app.ts"), """
      import token from 'cjs-consumer'
      console.log(token)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/bare_cjs_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "bundled-bare-cjs"
      refute js =~ ~r/\brequire\s*\(/
    end

    test "resolves package subpath without exports field" do
      File.mkdir_p!(Path.join(@fixture_dir, "node_modules/subpath-pkg/lib"))

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/package.json"),
        ~s({"name":"subpath-pkg","main":"index.js"})
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/index.js"),
        "module.exports = 'root'\n"
      )

      File.write!(
        Path.join(@fixture_dir, "node_modules/subpath-pkg/lib/utils.js"),
        "export const util = 'subpath-util'\n"
      )

      File.write!(Path.join(@fixture_dir, "src/subpath_app.ts"), """
      import { util } from 'subpath-pkg/lib/utils'
      console.log(util)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/subpath_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          node_modules: Path.join(@fixture_dir, "node_modules")
        )

      js = File.read!(result.js.path)
      assert js =~ "subpath-util"
    end

    test "skips .d.ts type declaration imports" do
      File.write!(Path.join(@fixture_dir, "src/types.d.ts"), """
      export type Foo = string
      """)

      File.write!(Path.join(@fixture_dir, "src/dts_app.ts"), """
      import { Foo } from './types'
      const x: Foo = 'hello'
      console.log(x)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "hello"
    end

    test "strips TypeScript from Vue SFCs with lang=ts" do
      File.write!(Path.join(@fixture_dir, "src/TsComponent.vue"), """
      <template><div>{{ msg }}</div></template>
      <script setup lang="ts">
      import { ref, type Ref } from 'vue'
      const msg: Ref<string> = ref('typed')
      </script>
      """)

      File.write!(Path.join(@fixture_dir, "src/vue_ts_app.ts"), """
      import TsComponent from './TsComponent.vue'
      console.log(TsComponent)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/vue_ts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          external: ["vue"]
        )

      js = File.read!(result.js.path)
      refute js =~ "Ref<string>"
      assert js =~ "ref("
    end

    test "resolves .js imports to .ts files when .js does not exist" do
      File.write!(Path.join(@fixture_dir, "src/utils.ts"), """
      export const helper = 'ts-resolved'
      """)

      File.write!(Path.join(@fixture_dir, "src/js_to_ts_app.ts"), """
      import { helper } from './utils.js'
      console.log(helper)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/js_to_ts_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "ts-resolved"
    end
  end
end
