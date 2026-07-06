defmodule Volt.Builder.CodeSplittingTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 code splitting" do
    test "manual chunks split modules into separate files" do
      lib_dir = Path.join(@fixture_dir, "src/lib")
      File.mkdir_p!(lib_dir)

      File.write!(Path.join(lib_dir, "helpers.ts"), """
      export function helper() { return 'help' }
      """)

      File.write!(Path.join(@fixture_dir, "src/chunked.ts"), """
      import { helper } from './lib/helpers'
      console.log(helper())
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/chunked.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false,
          chunks: %{"lib" => [Path.join(@fixture_dir, "src/lib")]}
        )

      assert result.chunks != nil
      chunk_files = Enum.map(result.chunks, &Path.basename(&1.path))
      assert Enum.any?(chunk_files, &(&1 =~ "lib"))
    end

    test "code splitting keeps entry bundle when entry has dynamic import" do
      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/dynamic_entry.ts"), """
      const $volt_ = (value: string) => value.toUpperCase()
      document.body.dataset.entry = $volt_('dynamic-entry')

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_entry.ts"),
          outdir: @outdir,
          name: "dynamic-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      assert Path.basename(result.js.path) == "dynamic-entry.js"

      entry_js = File.read!(Path.join(@outdir, "dynamic-entry.js"))
      assert entry_js =~ "dynamic-entry"
      assert entry_js =~ ~r/import\(["']\.\/dynamic-entry-lazy\.js["']\)/
      assert entry_js =~ "$volt_("
      refute entry_js =~ "import(\"dynamic-entry\")"

      lazy_js = File.read!(Path.join(@outdir, "dynamic-entry-lazy.js"))
      assert lazy_js =~ "lazy-loaded"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["dynamic-entry.js"]["file"] == "dynamic-entry.js"
      assert manifest["dynamic-entry.js"]["isEntry"]
      assert manifest["dynamic-entry.js"]["dynamicImports"] == ["dynamic-entry-lazy.js"]
      assert manifest["dynamic-entry-lazy.js"]["file"] == "dynamic-entry-lazy.js"
      refute manifest["dynamic-entry-lazy.js"]["isEntry"]
    end

    test "code splitting records async chunk css in manifest and preloads it" do
      File.write!(Path.join(@fixture_dir, "src/lazy.css"), ".lazy { color: red }")

      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      import './lazy.css'
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/dynamic_css_entry.ts"), """
      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/dynamic_css_entry.ts"),
          outdir: @outdir,
          name: "dynamic-css-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      assert entry_js =~ "__voltPreload"
      assert entry_js =~ "./dynamic-css-entry-lazy.css"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["dynamic-css-entry-lazy.js"]["css"] == ["dynamic-css-entry-lazy.css"]
      assert manifest["dynamic-css-entry.js"]["dynamicImports"] == ["dynamic-css-entry-lazy.js"]
      assert File.read!(Path.join(@outdir, "dynamic-css-entry-lazy.css")) =~ "lazy"
    end

    test "hashed code splitting keeps dynamic preload URLs and manifest files in sync" do
      File.write!(Path.join(@fixture_dir, "src/common.css"), ".common { color: blue }")
      File.write!(Path.join(@fixture_dir, "src/lazy-a.css"), ".lazy-a { color: red }")

      File.write!(Path.join(@fixture_dir, "src/shared.ts"), """
      import './common.css'
      export const shared = 'shared-value'
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy-a.ts"), """
      import { shared } from './shared'
      import './lazy-a.css'
      export const value = 'a-' + shared
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy-b.ts"), """
      import { shared } from './shared'
      export const value = 'b-' + shared
      """)

      File.write!(Path.join(@fixture_dir, "src/hashed_preload_entry.ts"), """
      export const loadA = () => import('./lazy-a')
      export const loadB = () => import('./lazy-b')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/hashed_preload_entry.ts"),
          outdir: @outdir,
          name: "hashed-preload",
          format: :esm,
          hash: true,
          minify: false,
          sourcemap: false
        )

      manifest = @outdir |> Path.join("manifest.json") |> File.read!() |> :json.decode()
      entry = manifest["hashed-preload.js"]
      entry_js = File.read!(result.js.path)

      assert entry["file"] == Path.basename(result.js.path)
      assert entry["dynamicImports"] |> Enum.sort() == entry["dynamicImports"]

      for {_key, %{"file" => file} = item} <- manifest do
        assert File.regular?(Path.join(@outdir, file))

        for css <- Map.get(item, "css", []) do
          assert File.regular?(Path.join(@outdir, css))
        end

        for asset <- Map.get(item, "assets", []) do
          assert File.regular?(Path.join(@outdir, asset))
        end
      end

      lazy_a = Enum.find(entry["dynamicImports"], &String.contains?(&1, "lazy-a"))
      lazy_b = Enum.find(entry["dynamicImports"], &String.contains?(&1, "lazy-b"))
      common = manifest[lazy_a]["imports"] |> List.first()
      common_css = manifest[common]["css"] |> List.first()
      lazy_css = manifest[lazy_a]["css"] |> List.first()

      assert entry_js =~ lazy_a
      assert entry_js =~ lazy_b
      assert entry_js =~ common
      assert entry_js =~ common_css
      assert entry_js =~ lazy_css
      assert File.read!(Path.join(@outdir, common_css)) =~ "common"
      assert File.read!(Path.join(@outdir, lazy_css)) =~ "lazy-a"
    end

    test "code splitting keeps dynamic facade when a module is also statically imported" do
      File.write!(Path.join(@fixture_dir, "src/facade.ts"), "export const value = 'facade-value'")

      File.write!(Path.join(@fixture_dir, "src/facade_entry.ts"), """
      import { value } from './facade'
      document.body.dataset.eager = value
      import('./facade').then((mod) => {
        document.body.dataset.lazy = mod.value
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/facade_entry.ts"),
          outdir: @outdir,
          name: "facade-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      async_js = File.read!(Path.join(@outdir, "facade-entry-facade.js"))

      assert entry_js =~ ~r/import\s*\{\s*value\s*\}\s*from\s*["']\.\/facade-entry-facade\.js["']/
      assert entry_js =~ ~r/import\(["']\.\/facade-entry-facade\.js["']\)/
      assert async_js =~ "facade-value"

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert manifest["facade-entry.js"]["isEntry"]
      assert manifest["facade-entry-facade.js"]["isEntry"] == false
      assert manifest["facade-entry.js"]["imports"] == ["facade-entry-facade.js"]
      assert manifest["facade-entry.js"]["dynamicImports"] == ["facade-entry-facade.js"]
    end

    test "code splitting rewrites chunk imports by exact virtual specifier" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/one/collide"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/two/collide"))

      File.write!(
        Path.join(@fixture_dir, "src/one/collide/index.ts"),
        "export const value = 'one-collide'"
      )

      File.write!(
        Path.join(@fixture_dir, "src/two/collide/index.ts"),
        "export const value = 'two-collide'"
      )

      File.write!(Path.join(@fixture_dir, "src/collision_entry.ts"), """
      export const loadOne = () => import('./one/collide')
      export const loadTwo = () => import('./two/collide')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/collision_entry.ts"),
          outdir: @outdir,
          name: "collision-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      entry_js = File.read!(result.js.path)
      chunk_files = result.chunks |> Enum.map(&Path.basename(&1.path)) |> Enum.sort()
      one_file = Enum.find(chunk_files, &(File.read!(Path.join(@outdir, &1)) =~ "one-collide"))
      two_file = Enum.find(chunk_files, &(File.read!(Path.join(@outdir, &1)) =~ "two-collide"))

      assert entry_js =~ one_file
      assert entry_js =~ two_file
      assert File.read!(Path.join(@outdir, one_file)) =~ "one-collide"
      assert File.read!(Path.join(@outdir, two_file)) =~ "two-collide"
    end

    test "code splitting rewrites minified dynamic import chunk URLs" do
      File.write!(
        Path.join(@fixture_dir, "src/lazy.ts"),
        "export const lazyValue = 'lazy-loaded'"
      )

      File.write!(Path.join(@fixture_dir, "src/minified_dynamic_entry.ts"), """
      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/minified_dynamic_entry.ts"),
          outdir: @outdir,
          name: "minified-dynamic-entry",
          format: :esm,
          hash: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "minified-dynamic-entry.js"))
      assert entry_js =~ "minified-dynamic-entry-lazy.js"
      refute entry_js =~ "lazy.ts"
      refute entry_js =~ ~r/import\([`'"]\.\/lazy[`'"]\)/
    end

    test "dynamic import protection avoids user identifier collisions" do
      File.write!(
        Path.join(@fixture_dir, "src/lazy.ts"),
        "export const lazyValue = 'lazy-loaded'"
      )

      File.write!(Path.join(@fixture_dir, "src/placeholder_collision_entry.ts"), """
      function __volt_dynamic_import__0__(value: string) {
        return value
      }

      document.body.dataset.placeholder = __volt_dynamic_import__0__('kept')

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/placeholder_collision_entry.ts"),
          outdir: @outdir,
          name: "placeholder-collision-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "placeholder-collision-entry.js"))
      assert entry_js =~ "function __volt_dynamic_import__0__"
      refute entry_js =~ "function import"
      assert entry_js =~ ~r/import\([`'"]\.\/placeholder-collision-entry-lazy\.js[`'"]\)/
    end

    test "code splitting includes alias modules outside the entry root" do
      File.mkdir_p!(Path.join(@fixture_dir, "shared"))

      File.write!(Path.join(@fixture_dir, "shared/rendered.ts"), """
      export const rendered = 'rendered-from-shared-root'
      """)

      File.write!(Path.join(@fixture_dir, "src/lazy.ts"), """
      export const lazyValue = 'lazy-loaded'
      """)

      File.write!(Path.join(@fixture_dir, "src/external_alias_entry.ts"), """
      import { rendered } from '@shared/rendered'

      document.body.dataset.rendered = rendered

      import('./lazy').then((mod) => {
        document.body.dataset.lazy = mod.lazyValue
      })
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/external_alias_entry.ts"),
          outdir: @outdir,
          name: "external-alias-entry",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false,
          aliases: %{"@shared" => Path.join(@fixture_dir, "shared")}
        )

      assert File.regular?(result.js.path)

      entry_js = File.read!(Path.join(@outdir, "external-alias-entry.js"))
      assert entry_js =~ "rendered-from-shared-root"
      assert entry_js =~ ~r/import\(["']\.\/external-alias-entry-lazy\.js["']\)/

      lazy_js = File.read!(Path.join(@outdir, "external-alias-entry-lazy.js"))
      assert lazy_js =~ "lazy-loaded"
    end
  end
end
