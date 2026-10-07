defmodule Volt.Builder.DeclarationsTest do
  use Volt.TestSupport.BuilderCase

  alias Volt.Builder.Declarations

  @node_modules Path.join(@fixture_dir, "node_modules")

  setup do
    File.mkdir_p!(Path.join(@node_modules, "vue"))

    File.write!(
      Path.join(@node_modules, "vue/package.json"),
      Jason.encode!(%{"name" => "vue", "main" => "index.js", "types" => "index.d.ts"})
    )

    File.write!(
      Path.join(@node_modules, "vue/index.js"),
      "export const ref = (v) => ({ value: v })"
    )

    File.write!(
      Path.join(@node_modules, "vue/index.d.ts"),
      "export declare const ref: <T>(v: T) => { value: T };"
    )

    :ok
  end

  defp write!(path, source) do
    path = Path.join(@fixture_dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
    path
  end

  defp context(plugins \\ []),
    do: %Volt.Builder.Context{node_modules: @node_modules, plugins: plugins}

  describe "bundle/2" do
    test "bundles the declarations the entry exports reach into one module" do
      write!("src/types.ts", """
      /** Where a recording goes. */
      export interface Target { url: string; retries?: number }
      export type Mode = 'live' | 'replay'
      export interface Unused { never: true }
      """)

      write!("src/recorder.ts", """
      import type { Target, Mode } from './types'
      import { ref } from 'vue'
      export class Recorder {
        mode: Mode = 'live'
        start(target: Target): void { console.log(target, ref(1)) }
      }
      export default class Session { id: string = '' }
      export const hidden: number = 1
      """)

      write!("src/extra.ts", """
      export const EXTRA: string = 'extra'
      export const ALSO: number = 2
      """)

      write!("src/index.ts", """
      import { ref } from 'vue'
      import Session from './recorder'
      import type { Target as RecordTarget } from './types'
      export { Recorder as Rec } from './recorder'
      export * from './extra'
      export type { Mode } from './types'
      export const current: RecordTarget | null = null
      export const session: typeof Session = Session
      export const counter: ReturnType<typeof ref<number>> = ref(0)
      declare module 'vue' { interface Augmented { fromIndex: true } }
      """)

      assert {:ok, dts} = Declarations.bundle(Path.join(@fixture_dir, "src/index.ts"), context())

      # Imports of packages are hoisted once; project imports are gone.
      assert String.starts_with?(dts, ~s(import { ref } from "vue";\n))
      assert length(Regex.scan(~r/from "vue"/, dts)) == 1
      refute dts =~ "./types"
      refute dts =~ "./recorder"

      # Declarations keep their docs and come before what refers to them.
      assert dts =~ "/** Where a recording goes. */\ninterface Target {"
      assert :binary.match(dts, "interface Target") < :binary.match(dts, "declare class Recorder")
      assert dts =~ "type Mode = \"live\" | \"replay\";"
      assert dts =~ "declare class Session {"
      assert dts =~ "declare const EXTRA: string;"
      assert dts =~ "declare const current: Target | null;"
      assert dts =~ "declare module \"vue\" {"

      # Only what the entry exports, under the entry's names.
      assert dts =~ "export { ALSO, EXTRA, Mode, Recorder as Rec, counter, current, session };\n"
      refute dts =~ "Unused"
      refute dts =~ "hidden"
      refute dts =~ "export declare"
    end

    test "tells apart the same name declared in two modules" do
      write!("src/a.ts", """
      /** A's options. */
      export interface Options { a: true }
      export const configureA: (o: Options) => void = () => {}
      """)

      write!("src/b.ts", """
      export interface Options { b: true }
      export const configureB: (o: Options) => Options = (o) => o
      """)

      write!("src/index.ts", """
      export { configureA } from './a'
      export { configureB } from './b'
      export interface Options { index: true }
      export const configure: (o: Options) => void = () => {}
      """)

      assert {:ok, dts} = Declarations.bundle(Path.join(@fixture_dir, "src/index.ts"), context())

      assert dts =~ "interface Options {\n\tindex: true;\n}"
      assert dts =~ "/** A's options. */\ninterface Options$1 {\n\ta: true;\n}"
      assert dts =~ "interface Options$2 {\n\tb: true;\n}"
      assert dts =~ "declare const configureA: (o: Options$1) => void;"
      assert dts =~ "declare const configureB: (o: Options$2) => Options$2;"
      assert dts =~ "declare const configure: (o: Options) => void;"
      assert dts =~ "export { Options, configure, configureA, configureB };"
    end

    test "reports the module whose declarations cannot be emitted" do
      write!("src/inferred.ts", "export function size() { return compute() }\n")
      write!("src/index.ts", "export { size } from './inferred'\n")

      assert {:error, {:declarations, path, [%{message: "TS9007" <> _, position: {1, 17}}]}} =
               Declarations.bundle(Path.join(@fixture_dir, "src/index.ts"), context())

      assert path == Path.join(@fixture_dir, "src/inferred.ts")
    end

    test "names the constructs it does not bundle" do
      write!("src/ns.ts", "export const n: number = 1\n")
      write!("src/index.ts", "import * as ns from './ns'\nexport const all: typeof ns = ns\n")

      assert {:error, {:declarations, _path, "`import * as`" <> _}} =
               Declarations.bundle(Path.join(@fixture_dir, "src/index.ts"), context())

      write!("src/index.ts", "export * as ns from './ns'\n")

      assert {:error, {:declarations, _path, "`export * as ns`" <> _}} =
               Declarations.bundle(Path.join(@fixture_dir, "src/index.ts"), context())
    end

    test "declares a component through its plugin" do
      write!("src/Button.vue", """
      <script setup lang="ts">
      defineProps<{ variant?: 'primary' | 'ghost' }>()
      </script>
      <template><button /></template>
      """)

      write!("src/index.ts", """
      import Button from './Button.vue'
      export const button: typeof Button = Button
      """)

      assert {:ok, dts} =
               Declarations.bundle(
                 Path.join(@fixture_dir, "src/index.ts"),
                 context([Volt.Plugin.Vue])
               )

      assert dts =~ "type Props = { variant?: 'primary' | 'ghost' };"
      assert dts =~ "declare const __vize_component__:"
      assert dts =~ "declare const button: typeof __vize_component__;"
      assert dts =~ "export { button };"
    end
  end

  describe "build/1 with declarations" do
    test "writes one .d.ts per entry beside its bundle, without a hash" do
      write!("src/lib.ts", """
      import { ref } from 'vue'
      export const count: ReturnType<typeof ref<number>> = ref(0)
      export function reset(): void { count.value = 0 }
      """)

      assert {:ok, result} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/lib.ts"),
                 outdir: @outdir,
                 node_modules: @node_modules,
                 format: :esm,
                 name: "lib",
                 declarations: true,
                 minify: false,
                 sourcemap: false
               )

      assert [%Volt.Builder.OutputFile{path: path}] = result.declarations
      assert path == Path.join(@outdir, "lib.d.ts")
      assert File.read!(path) =~ "export { count, reset };"
      assert Path.basename(result.js.path) =~ ~r/^lib-[a-f0-9]+\.js$/
    end

    test "writes declarations for each of several ESM entries" do
      write!("src/one.ts", "export const one: number = 1\n")

      write!(
        "src/two.ts",
        "import { one } from './one'\nexport const two: typeof one = one + 1\n"
      )

      assert {:ok, result} =
               Volt.Builder.build(
                 entry: [
                   Path.join(@fixture_dir, "src/one.ts"),
                   Path.join(@fixture_dir, "src/two.ts")
                 ],
                 outdir: @outdir,
                 node_modules: @node_modules,
                 format: :esm,
                 declarations: true,
                 minify: false,
                 sourcemap: false
               )

      assert Enum.map(result.declarations, &Path.basename(&1.path)) == ["one.d.ts", "two.d.ts"]
      assert File.read!(Path.join(@outdir, "two.d.ts")) =~ "declare const one: number;"
    end

    test "fails the build with the module that has no explicit types" do
      write!("src/lib.ts", "export const value = compute()\n")

      assert {:error, {:declarations, path, [%{message: "TS9010" <> _}]}} =
               Volt.Builder.build(
                 entry: Path.join(@fixture_dir, "src/lib.ts"),
                 outdir: @outdir,
                 node_modules: @node_modules,
                 format: :esm,
                 declarations: true
               )

      assert path == Path.join(@fixture_dir, "src/lib.ts")
    end
  end
end
