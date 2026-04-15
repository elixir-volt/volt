defmodule Volt.CSS.ModulesTest do
  use ExUnit.Case, async: true

  describe "css_module?/1" do
    test "identifies .module.css files" do
      assert Volt.CSS.Modules.css_module?("button.module.css")
      assert Volt.CSS.Modules.css_module?("path/to/style.module.css")
    end

    test "rejects non-module CSS" do
      refute Volt.CSS.Modules.css_module?("app.css")
      refute Volt.CSS.Modules.css_module?("module.css.bak")
    end
  end

  describe "compile/2" do
    test "generates scoped class names" do
      {:ok, js, css} = Volt.CSS.Modules.compile(".primary { color: blue }", "button.module.css")

      assert js =~ "export default"
      assert js =~ "primary"
      refute css =~ ~r/\.primary[^_]/
      assert css =~ "primary"
      assert css =~ "color"
    end

    test "handles multiple classes" do
      source = """
      .title { font-size: 2em }
      .subtitle { font-size: 1.2em }
      .active { color: green }
      """

      {:ok, js, css} = Volt.CSS.Modules.compile(source, "heading.module.css")

      mapping =
        js
        |> String.trim_leading("export default ")
        |> String.trim_trailing(";\n")
        |> Jason.decode!()

      assert Map.has_key?(mapping, "title")
      assert Map.has_key?(mapping, "subtitle")
      assert Map.has_key?(mapping, "active")

      for {_original, scoped} <- mapping do
        assert css =~ scoped
      end
    end

    test "different files produce different scoped names" do
      {:ok, js1, _css1} = Volt.CSS.Modules.compile(".box { }", "a.module.css")
      {:ok, js2, _css2} = Volt.CSS.Modules.compile(".box { }", "b.module.css")

      map1 =
        js1
        |> String.trim_leading("export default ")
        |> String.trim_trailing(";\n")
        |> Jason.decode!()

      map2 =
        js2
        |> String.trim_leading("export default ")
        |> String.trim_trailing(";\n")
        |> Jason.decode!()

      assert map1["box"] != map2["box"]
    end
  end

  describe "Pipeline integration" do
    test "compiles .module.css through pipeline" do
      {:ok, result} =
        Volt.Pipeline.compile("button.module.css", ".btn { color: red }")

      assert result.code =~ "export default"
      assert result.css =~ "btn"
      assert result.css =~ "color"
    end
  end
end
