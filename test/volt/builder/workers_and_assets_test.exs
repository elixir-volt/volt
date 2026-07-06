defmodule Volt.Builder.WorkersAndAssetsTest do
  use Volt.TestSupport.BuilderCase

  describe "build/1 workers, assets, and externals" do
    test "rewrites workers by importer path instead of basename" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/a"))
      File.mkdir_p!(Path.join(@fixture_dir, "src/b"))

      File.write!(Path.join(@fixture_dir, "src/a/worker.ts"), "self.postMessage('worker-a')")
      File.write!(Path.join(@fixture_dir, "src/b/worker.ts"), "self.postMessage('worker-b')")

      File.write!(Path.join(@fixture_dir, "src/a/mod.ts"), """
      new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      """)

      File.write!(Path.join(@fixture_dir, "src/b/mod.ts"), """
      new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      """)

      File.write!(Path.join(@fixture_dir, "src/worker_collision_app.ts"), """
      export const loadA = () => import('./a/mod')
      export const loadB = () => import('./b/mod')
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker_collision_app.ts"),
          outdir: @outdir,
          name: "worker-collision",
          format: :esm,
          hash: false,
          minify: false,
          sourcemap: false
        )

      worker_files = Path.wildcard(Path.join(@outdir, "worker-*.js"))

      chunk_sources =
        result.chunks
        |> Enum.reject(&(&1.type == :entry))
        |> Enum.map(fn chunk -> chunk.path |> File.read!() end)

      worker_refs =
        chunk_sources
        |> Enum.flat_map(&Regex.scan(~r/worker-[a-f0-9]{8}\.js/, &1))
        |> List.flatten()

      assert length(Enum.uniq(worker_refs)) == 2
      assert Enum.all?(worker_refs, &File.regular?(Path.join(@outdir, &1)))
      assert Enum.any?(worker_files, &(File.read!(&1) =~ "worker-a"))
      assert Enum.any?(worker_files, &(File.read!(&1) =~ "worker-b"))
    end

    test "builds worker entry as a standalone bundle" do
      File.write!(Path.join(@fixture_dir, "src/worker.ts"), "self.postMessage('ready')")

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      assert Path.basename(result.js.path) =~ ~r/^worker-[a-f0-9]{8}\.js$/
    end

    test "rewrites worker URL to hashed filename in parent bundle" do
      File.write!(Path.join(@fixture_dir, "src/worker.ts"), "self.postMessage('ready')")

      File.write!(Path.join(@fixture_dir, "src/worker_app.ts"), """
      const worker = new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
      console.log(worker)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/worker_app.ts"),
          outdir: @outdir,
          minify: false,
          sourcemap: false
        )

      assert File.regular?(result.js.path)
      js = File.read!(result.js.path)
      assert js =~ "new Worker"
      assert js =~ ~r/worker-[a-f0-9]{8}\.js/

      manifest = Path.join(@outdir, "manifest.json") |> File.read!() |> :json.decode()
      assert Map.has_key?(manifest, "worker_app.js")
    end

    test "accepts custom name" do
      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/app.ts"),
          outdir: @outdir,
          name: "bundle",
          minify: false,
          sourcemap: false
        )

      assert Path.basename(result.js.path) =~ "bundle-"
    end

    test "returns error for missing entry" do
      {:error, _} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/missing.ts"),
          outdir: @outdir
        )
    end

    test "bundles bare package CSS imports" do
      css_pkg_dir = Path.join(@fixture_dir, "vendor/csslib")
      File.mkdir_p!(css_pkg_dir)
      File.write!(Path.join(css_pkg_dir, "theme.css"), ".from-node-module { color: red }")

      File.write!(Path.join(css_pkg_dir, "package.json"), ~s({
        "name": "csslib",
        "exports": { "./theme.css": "./theme.css" }
      }))

      File.write!(Path.join(@fixture_dir, "src/package_css.css"), ~s(@import "csslib/theme.css";))

      File.write!(Path.join(@fixture_dir, "src/package_css.ts"), """
      import './package_css.css'
      """)

      assert {:ok, _result} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/package_css.ts"),
                 outdir: @outdir,
                 minify: false,
                 format: :esm,
                 resolve_dirs: [Path.join(@fixture_dir, "vendor")]
               )

      css = @outdir |> Path.join("*.css") |> Path.wildcard() |> List.first() |> File.read!()
      assert css =~ ".from-node-module"
    end

    test "raw query exports non-asset file contents" do
      File.write!(Path.join(@fixture_dir, "src/note.md"), "# Hello\n\nfrom markdown")

      File.write!(Path.join(@fixture_dir, "src/raw_markdown.ts"), """
      import note from './note.md?raw'
      console.log(note)
      """)

      assert {:ok, _result} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/raw_markdown.ts"),
                 outdir: @outdir,
                 minify: false,
                 format: :esm
               )

      js_path =
        (Path.wildcard(Path.join(@outdir, "*.js")) ++ Path.wildcard(Path.join(@outdir, "js/*.js")))
        |> List.first()

      js = File.read!(js_path)
      assert js =~ "# Hello\\n\\nfrom markdown"
    end

    test "unresolved existing package subpaths fail build instead of becoming implicit globals" do
      package_dir = Path.join(@fixture_dir, "vendor/dirlib")
      File.mkdir_p!(package_dir)

      File.write!(
        Path.join(package_dir, "package.json"),
        ~s({"name":"dirlib","main":"./index.js"})
      )

      File.write!(Path.join(package_dir, "index.js"), "export const ROOT = true")

      File.write!(Path.join(@fixture_dir, "src/missing_package_subpath.ts"), """
      import { nope } from 'dirlib/missing'
      console.log(nope)
      """)

      assert {:error, {:not_found, "dirlib/missing"}} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/missing_package_subpath.ts"),
                 outdir: @outdir,
                 minify: false,
                 format: :iife,
                 resolve_dirs: [Path.join(@fixture_dir, "vendor")]
               )
    end

    test "external imports become global access in IIFE" do
      File.write!(Path.join(@fixture_dir, "src/vue_app.ts"), """
      import { ref, computed } from 'vue'
      const count = ref(0)
      const double = computed(() => count.value * 2)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/vue_app.ts"),
          outdir: @outdir,
          external: ["vue"],
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "const { ref, computed } = Vue;"
      assert js =~ "ref(0)"
      refute js =~ ~s(from 'vue')
    end

    test "external with explicit global name" do
      File.write!(Path.join(@fixture_dir, "src/ext_app.ts"), """
      import { ref } from 'vue'
      ref(0)
      """)

      {:ok, result} =
        Volt.Builder.build(
          entry: Path.join(@fixture_dir, "src/ext_app.ts"),
          outdir: @outdir,
          external: %{"vue" => "MyVue"},
          minify: false,
          sourcemap: false
        )

      js = File.read!(result.js.path)
      assert js =~ "const { ref } = MyVue;"
    end
  end
end
