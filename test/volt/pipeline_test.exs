defmodule Volt.PipelineTest do
  use ExUnit.Case, async: true

  defmodule UppercasePlugin do
    @behaviour Volt.Plugin

    @impl true
    def name, do: "uppercase"

    @impl true
    def transform(code, _path) do
      {:ok, String.upcase(code)}
    end
  end

  describe "compile/3 with TypeScript" do
    test "strips types and returns sourcemap" do
      {:ok, result} = Volt.Pipeline.compile("app.ts", "const x: number = 42")
      assert result.code =~ "const x = 42"
      assert is_binary(result.sourcemap)
      assert result.css == nil
      assert result.hashes == nil
    end

    test "compiles JSX" do
      {:ok, result} = Volt.Pipeline.compile("app.tsx", "<div />")
      assert result.code =~ "jsx"
    end

    test "applies target downleveling" do
      {:ok, result} = Volt.Pipeline.compile("app.js", "const x = a ?? b", target: :es2019)
      refute result.code =~ "??"
    end

    test "injects import.meta.env defines" do
      {:ok, result} =
        Volt.Pipeline.compile("app.ts", "console.log(import.meta.env.MODE, import.meta.env.DEV)",
          define: %{
            "import.meta.env.MODE" => ~s("development"),
            "import.meta.env.DEV" => "true"
          }
        )

      assert result.code =~ ~s(import.meta.env = { "DEV": true, "MODE": "development" };)
      assert result.code =~ "console.log(import.meta.env.MODE, import.meta.env.DEV)"
      assert result.sourcemap == nil
    end

    test "supports runtime access to injected import.meta.env" do
      source = "const key = 'MODE'; console.log(import.meta.env[key], import.meta.env)"

      {:ok, result} =
        Volt.Pipeline.compile("app.ts", source,
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      assert result.code =~ ~s("MODE": "development")
      assert result.code =~ "import.meta.env[key]"
      assert result.code =~ "console.log(import.meta.env[key], import.meta.env)"
    end

    test "supports destructuring import.meta.env" do
      {:ok, result} =
        Volt.Pipeline.compile("app.ts", "const { MODE } = import.meta.env; console.log(MODE)",
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      assert result.code =~ ~s("MODE": "development")
      assert result.code =~ "const { MODE } = import.meta.env"
    end

    test "supports optional access to import.meta.env" do
      {:ok, result} =
        Volt.Pipeline.compile("app.ts", "console.log(import.meta?.env?.MODE)",
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      assert result.code =~ ~s("MODE": "development")
      assert result.code =~ "import.meta?.env?.MODE"
    end

    test "does not inject import.meta.env for string literals or unrelated import.meta properties" do
      source = "console.log('import.meta.env', import.meta.url, foo.env)"

      {:ok, result} =
        Volt.Pipeline.compile("app.ts", source,
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      refute result.code =~ "import.meta.env ="
      assert result.code =~ "import.meta.url"
      assert result.code =~ ~s("import.meta.env")
    end

    test "leaves non import.meta.env defines unchanged" do
      source = "function f(process) { return process.env.NODE_ENV }"

      {:ok, result} =
        Volt.Pipeline.compile("app.js", source,
          define: %{"process.env.NODE_ENV" => ~s("development")}
        )

      assert result.code =~ "process.env.NODE_ENV"
    end
  end

  describe "compile/3 with Vue SFC" do
    test "compiles a simple SFC" do
      source = """
      <template><div>{{ msg }}</div></template>
      <script setup>const msg = 'hi'</script>
      """

      {:ok, result} = Volt.Pipeline.compile("App.vue", source)
      assert result.code =~ "msg"
      assert result.hashes.template != nil
    end

    test "applies JavaScript postprocess transforms to compiled SFC output" do
      dir =
        Path.join(System.tmp_dir!(), "volt-vue-postprocess-#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(dir, "pages"))
      File.write!(Path.join(dir, "pages/home.ts"), "export const page = 'home'")
      on_exit(fn -> File.rm_rf!(dir) end)

      source = """
      <script setup lang="ts">
      const pages = import.meta.glob('./pages/*.ts', { eager: true })
      const mode = import.meta.env.MODE
      </script>
      <template><p>{{ mode }}</p></template>
      """

      {:ok, result} =
        Volt.Pipeline.compile(Path.join(dir, "App.vue"), source,
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      refute result.code =~ "import.meta.glob"
      assert result.code =~ "./pages/home.ts"
      assert result.code =~ ~s(import.meta.env = { "MODE": "development" };)
      assert result.code =~ "import.meta.env.MODE"
    end

    test "returns CSS from scoped styles" do
      source = """
      <template><div class="box">hi</div></template>
      <style scoped>.box { color: red }</style>
      """

      {:ok, result} = Volt.Pipeline.compile("App.vue", source)
      assert is_binary(result.css)
    end
  end

  describe "compile/3 with Svelte" do
    test "applies JavaScript postprocess transforms to compiled Svelte output" do
      dir =
        Path.join(
          System.tmp_dir!(),
          "volt-svelte-postprocess-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(Path.join(dir, "pages"))
      File.write!(Path.join(dir, "pages/home.ts"), "export const page = 'home'")
      on_exit(fn -> File.rm_rf!(dir) end)

      source = """
      <script lang="ts">
        const pages = import.meta.glob('./pages/*.ts', { eager: true })
        const mode = import.meta.env.MODE
      </script>
      <p>{mode}</p>
      """

      {:ok, result} =
        Volt.Pipeline.compile(Path.join(dir, "App.svelte"), source,
          define: %{"import.meta.env.MODE" => ~s("development")}
        )

      refute result.code =~ "import.meta.glob"
      assert result.code =~ "./pages/home.ts"
      assert result.code =~ ~s(import.meta.env = { "MODE": "development" };)
      assert result.code =~ "import.meta.env.MODE"
    end
  end

  describe "compile/3 with plugin output" do
    test "applies JavaScript postprocess transforms after custom plugin compilation" do
      dir =
        Path.join(
          System.tmp_dir!(),
          "volt-plugin-postprocess-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(Path.join(dir, "pages"))
      File.write!(Path.join(dir, "pages/custom.ts"), "export const custom = true")
      on_exit(fn -> File.rm_rf!(dir) end)

      defmodule PostprocessCompilerPlugin do
        @behaviour Volt.Plugin
        def name, do: "postprocess-compiler"
        def extensions(:compile), do: [".future"]
        def extensions(_), do: []

        def compile(path, _source, _opts) do
          if Path.extname(path) == ".future" do
            {:ok,
             %{
               code:
                 "const pages = import.meta.glob('./pages/*.ts', { eager: true })\nconst mode = import.meta.env.MODE",
               sourcemap: nil,
               css: nil,
               hashes: nil
             }}
          end
        end
      end

      assert {:ok, result} =
               Volt.Pipeline.compile(Path.join(dir, "component.future"), "ignored",
                 plugins: [PostprocessCompilerPlugin],
                 define: %{"import.meta.env.MODE" => ~s("development")}
               )

      refute result.code =~ "import.meta.glob"
      assert result.code =~ "./pages/custom.ts"
      assert result.code =~ ~s(import.meta.env = { "MODE": "development" };)
    end

    test "plugins can compile custom file types" do
      defmodule CustomCompilerPlugin do
        @behaviour Volt.Plugin
        def name, do: "custom-compiler"
        def extensions(:compile), do: [".custom"]
        def extensions(_), do: []

        def compile("component.custom", source, _opts) do
          {:ok,
           %{code: "export default #{inspect(source)}", sourcemap: nil, css: nil, hashes: nil}}
        end

        def compile(_, _, _), do: nil
      end

      assert {:ok, %{code: ~s(export default "hello")}} =
               Volt.Pipeline.compile("component.custom", "hello", plugins: [CustomCompilerPlugin])
    end

    test "plugins receive compiled output" do
      {:ok, result} =
        Volt.Pipeline.compile("app.ts", "const x: number = 42", plugins: [UppercasePlugin])

      assert result.code == String.upcase(result.code)
    end
  end

  describe "compile/3 with CSS" do
    test "passes through CSS" do
      {:ok, result} = Volt.Pipeline.compile("app.css", ".foo { color: red }")
      assert result.code =~ "color"
    end

    test "minifies CSS" do
      {:ok, result} = Volt.Pipeline.compile("app.css", ".foo {\n  color: red;\n}", minify: true)
      refute result.code =~ "\n"
    end

    test "compiles SCSS with native Sass support" do
      {:ok, result} =
        Volt.Pipeline.compile(
          "app.scss",
          "$brand: #639; .button { color: $brand; &:hover { opacity: .8; } }"
        )

      assert result.code =~ "#639"
      assert result.code =~ ".button:hover"
    end

    test "compiles indented Sass syntax" do
      source = "$brand: red\n.button\n  color: $brand"
      assert {:ok, result} = Volt.Pipeline.compile("app.sass", source)
      assert result.code =~ "color: red"
    end

    test "resolves SCSS partials relative to the source file" do
      dir = Path.join(System.tmp_dir!(), "volt-scss-import-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "_tokens.scss"), "$brand: rebeccapurple;")
      File.write!(Path.join(dir, "app.scss"), "@use 'tokens' as *; .app { color: $brand; }")
      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "app.scss")
      assert {:ok, result} = Volt.Pipeline.compile(path, File.read!(path))
      assert result.code =~ "#639"
    end

    test "returns Sass compilation errors" do
      assert {:error, error} = Volt.Pipeline.compile("app.scss", ".app { color: $missing; }")
      assert error =~ "Undefined variable"
    end

    test "inlines @import from disk" do
      dir = Path.join(System.tmp_dir!(), "volt-css-import-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "reset.css"), "* { margin: 0 }")
      File.write!(Path.join(dir, "app.css"), "@import \"./reset.css\";\n.app { color: red }")

      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "app.css")
      {:ok, result} = Volt.Pipeline.compile(path, File.read!(path))
      assert result.code =~ "margin"
      assert result.code =~ "color"
      refute result.code =~ "@import"
    end

    test "inlines nested @import dependencies from disk" do
      dir =
        Path.join(
          System.tmp_dir!(),
          "volt-css-nested-import-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "tokens.css"), ":root { --brand: rebeccapurple }")

      File.write!(
        Path.join(dir, "theme.css"),
        "@import \"./tokens.css\";\n.button { color: var(--brand) }"
      )

      File.write!(Path.join(dir, "app.css"), "@import \"./theme.css\";\n.app { display: grid }")

      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "app.css")
      {:ok, result} = Volt.Pipeline.compile(path, File.read!(path), minify: false)

      assert result.code =~ "--brand"
      assert result.code =~ "rebeccapurple"
      assert result.code =~ "button"
      assert result.code =~ "display: grid"
      refute result.code =~ "@import"
    end
  end

  describe "compile/3 with import rewriting" do
    test "rewrites imports when rewrite_import is provided" do
      source = "import { ref } from 'vue'\nconst x = ref(0)"

      {:ok, result} =
        Volt.Pipeline.compile("app.ts", source,
          rewrite_import: fn
            "vue" -> {:rewrite, "/@vendor/vue.js"}
            _ -> :keep
          end
        )

      assert result.code =~ "/@vendor/vue.js"
      refute result.code =~ "'vue'"
    end

    test "skips rewriting when no rewrite_import given" do
      {:ok, result} = Volt.Pipeline.compile("app.ts", "import { ref } from 'vue'\nref(0)")
      assert result.code =~ "vue"
    end
  end

  describe "compile/3 with JSON" do
    test "wraps JSON as ES module" do
      {:ok, result} = Volt.Pipeline.compile("data.json", ~s({"key":"value"}))
      assert result.code =~ "export default"
      assert result.code =~ ~s("key")
    end
  end

  describe "compile/3 with CSS Modules" do
    test "compiles .module.css to JS + scoped CSS" do
      {:ok, result} = Volt.Pipeline.compile("btn.module.css", ".btn { color: red }")
      assert result.code =~ "export default"
      assert result.css =~ "btn"
      assert result.css =~ "color"
    end

    test "preprocesses .module.scss before CSS Modules scoping" do
      source = "$brand: #639; .button { color: $brand; &:hover { opacity: .8; } }"
      assert {:ok, result} = Volt.Pipeline.compile("button.module.scss", source)
      assert result.code =~ "export default"
      assert result.code =~ "button"
      assert result.css =~ "#639"
      assert result.css =~ ":hover"
    end
  end

  describe "compile/3 errors" do
    test "returns error for unsupported extensions" do
      {:error, {:unsupported, ".xyz"}} = Volt.Pipeline.compile("data.xyz", "binary")
    end

    test "returns error for invalid TypeScript" do
      {:error, errors} = Volt.Pipeline.compile("bad.ts", "const = ;")
      assert is_list(errors)
    end
  end
end
