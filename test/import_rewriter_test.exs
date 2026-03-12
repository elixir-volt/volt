defmodule Volt.ImportRewriterTest do
  use ExUnit.Case, async: true

  doctest Volt.ImportRewriter

  describe "rewrite/3" do
    test "rewrites matching bare imports" do
      source = "import { ref } from 'vue'\nimport a from './local'"

      {:ok, result} =
        Volt.ImportRewriter.rewrite(source, "test.ts", fn
          "vue" -> {:rewrite, "/@vendor/vue.js"}
          _ -> :keep
        end)

      assert result =~ "/@vendor/vue.js"
      assert result =~ "'./local'"
    end

    test "rewrites multiple imports" do
      source = "import { ref } from 'vue'\nimport { h } from 'preact'"

      {:ok, result} =
        Volt.ImportRewriter.rewrite(source, "test.ts", fn
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
        Volt.ImportRewriter.rewrite(source, "test.ts", fn
          "bar" -> {:rewrite, "./bar.js"}
          _ -> :keep
        end)

      assert result =~ "'./bar.js'"
    end

    test "rewrites export *" do
      source = "export * from 'utils'"

      {:ok, result} =
        Volt.ImportRewriter.rewrite(source, "test.ts", fn
          "utils" -> {:rewrite, "./utils.js"}
          _ -> :keep
        end)

      assert result =~ "'./utils.js'"
    end

    test "handles dynamic imports" do
      source = "const m = import('lodash')"

      {:ok, result} =
        Volt.ImportRewriter.rewrite(source, "test.js", fn
          "lodash" -> {:rewrite, "/@vendor/lodash.js"}
          _ -> :keep
        end)

      assert result =~ "/@vendor/lodash.js"
    end

    test "keeps unmatched imports unchanged" do
      source = "import { ref } from 'vue'"

      {:ok, result} =
        Volt.ImportRewriter.rewrite(source, "test.ts", fn _ -> :keep end)

      assert result == source
    end

    test "returns parse errors" do
      {:error, errors} = Volt.ImportRewriter.rewrite("const = ;", "bad.js", fn _ -> :keep end)
      assert is_list(errors)
    end
  end

  describe "rewrite_map/3" do
    test "rewrites from a static map" do
      source = "import { ref } from 'vue'\nimport { h } from 'preact'"

      {:ok, result} =
        Volt.ImportRewriter.rewrite_map(source, "test.ts", %{
          "vue" => "/@vendor/vue.js",
          "preact" => "/@vendor/preact.js"
        })

      assert result =~ "/@vendor/vue.js"
      assert result =~ "/@vendor/preact.js"
    end

    test "ignores specifiers not in map" do
      source = "import a from './local'"
      {:ok, result} = Volt.ImportRewriter.rewrite_map(source, "test.ts", %{"vue" => "/v.js"})
      assert result == source
    end
  end

  describe "rewrite!/3" do
    test "returns string on success" do
      result =
        Volt.ImportRewriter.rewrite!("import a from 'x'", "test.ts", fn
          "x" -> {:rewrite, "y"}
          _ -> :keep
        end)

      assert result =~ "'y'"
    end

    test "raises on parse error" do
      assert_raise RuntimeError, fn ->
        Volt.ImportRewriter.rewrite!("const = ;", "bad.js", fn _ -> :keep end)
      end
    end
  end
end
