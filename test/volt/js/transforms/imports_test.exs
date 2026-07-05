defmodule Volt.JS.Transforms.ImportsTest do
  use ExUnit.Case, async: true

  doctest Volt.JS.Transforms.Imports

  import Volt.Test.Sigils

  describe "rewrite/3" do
    test "rewrites matching bare imports" do
      source = ~JS"""
      import { ref } from 'vue'
      import a from './local'
      """

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn
          "vue" -> {:rewrite, "/@vendor/vue.js"}
          _ -> :keep
        end)

      assert result =~ "/@vendor/vue.js"
      assert result =~ "'./local'"
    end

    test "rewrites multiple imports" do
      source = "import { ref } from 'vue'\nimport { h } from 'preact'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn
          "vue" -> {:rewrite, "/@vendor/vue.js"}
          "preact" -> {:rewrite, "/@vendor/preact.js"}
          _ -> :keep
        end)

      assert result =~ "/@vendor/vue.js"
      assert result =~ "/@vendor/preact.js"
    end

    test "rewrites re-exports" do
      source = "export { foo } from 'bar'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn
          "bar" -> {:rewrite, "./bar.js"}
          _ -> :keep
        end)

      assert result =~ ~s("./bar.js")
    end

    test "rewrites export *" do
      source = "export * from 'utils'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn
          "utils" -> {:rewrite, "./utils.js"}
          _ -> :keep
        end)

      assert result =~ ~s("./utils.js")
    end

    test "handles dynamic imports" do
      source = ~JS"const m = import('lodash')"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.js", fn
          "lodash" -> {:rewrite, "/@vendor/lodash.js"}
          _ -> :keep
        end)

      assert result =~ "/@vendor/lodash.js"
    end

    test "escapes rewritten specifiers as JavaScript strings" do
      source = "import x from 'pkg'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn
          "pkg" -> {:rewrite, "./has'quote\\file.js"}
          _ -> :keep
        end)

      assert result =~ ~s("./has'quote\\\\file.js")
      assert {:ok, _ast} = OXC.parse(result, "test.ts")
    end

    test "keeps unmatched imports unchanged" do
      source = ~JS"import { ref } from 'vue'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite(source, "test.ts", fn _ -> :keep end)

      assert result == source
    end

    test "returns parse errors" do
      {:error, errors} =
        Volt.JS.Transforms.Imports.rewrite("const = ;", "bad.js", fn _ -> :keep end)

      assert is_list(errors)
    end
  end

  describe "rewrite_map/3" do
    test "rewrites from a static map" do
      source = "import { ref } from 'vue'\nimport { h } from 'preact'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite_map(source, "test.ts", %{
          "vue" => "/@vendor/vue.js",
          "preact" => "/@vendor/preact.js"
        })

      assert result =~ "/@vendor/vue.js"
      assert result =~ "/@vendor/preact.js"
    end

    test "ignores specifiers not in map" do
      source = "import a from './local'"

      {:ok, result} =
        Volt.JS.Transforms.Imports.rewrite_map(source, "test.ts", %{"vue" => "/v.js"})

      assert result == source
    end
  end

  describe "rewrite!/3" do
    test "returns string on success" do
      result =
        Volt.JS.Transforms.Imports.rewrite!("import a from 'x'", "test.ts", fn
          "x" -> {:rewrite, "y"}
          _ -> :keep
        end)

      assert result =~ ~s("y")
    end

    test "raises on parse error" do
      assert_raise RuntimeError, fn ->
        Volt.JS.Transforms.Imports.rewrite!("const = ;", "bad.js", fn _ -> :keep end)
      end
    end
  end
end
