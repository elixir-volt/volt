defmodule Volt.PipelineTest do
  use ExUnit.Case, async: true

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
      {:ok, result} = Volt.Pipeline.compile("app.js", "const x = a ?? b", target: "es2019")
      refute result.code =~ "??"
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

    test "returns CSS from scoped styles" do
      source = """
      <template><div class="box">hi</div></template>
      <style scoped>.box { color: red }</style>
      """

      {:ok, result} = Volt.Pipeline.compile("App.vue", source)
      assert is_binary(result.css)
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
