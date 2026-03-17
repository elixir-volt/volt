defmodule Volt.CSSModulesTest do
  use ExUnit.Case, async: true

  describe "css_module?/1" do
    test "identifies .module.css files" do
      assert Volt.CSSModules.css_module?("button.module.css")
      assert Volt.CSSModules.css_module?("path/to/style.module.css")
    end

    test "rejects non-module CSS" do
      refute Volt.CSSModules.css_module?("app.css")
      refute Volt.CSSModules.css_module?("module.css.bak")
    end
  end

  describe "compile/2" do
    test "generates scoped class names" do
      {:ok, js, css} = Volt.CSSModules.compile(".primary { color: blue }", "button.module.css")

      assert js =~ "export default"
      assert js =~ "primary"
      assert css =~ "_primary_"
      refute css =~ ".primary "
    end

    test "handles multiple classes" do
      source = """
      .title { font-size: 2em }
      .subtitle { font-size: 1.2em }
      .active { color: green }
      """

      {:ok, js, css} = Volt.CSSModules.compile(source, "heading.module.css")

      mapping = Jason.decode!(String.trim_leading(js, "export default ") |> String.trim_trailing(";\n"))
      assert Map.has_key?(mapping, "title")
      assert Map.has_key?(mapping, "subtitle")
      assert Map.has_key?(mapping, "active")

      for {_original, scoped} <- mapping do
        assert css =~ scoped
      end
    end

    test "different files produce different hashes" do
      {:ok, _js1, css1} = Volt.CSSModules.compile(".box { }", "a.module.css")
      {:ok, _js2, css2} = Volt.CSSModules.compile(".box { }", "b.module.css")

      [scoped1] = Regex.run(~r/\._box_\w+/, css1)
      [scoped2] = Regex.run(~r/\._box_\w+/, css2)
      assert scoped1 != scoped2
    end
  end

  describe "Pipeline integration" do
    test "compiles .module.css through pipeline" do
      {:ok, result} =
        Volt.Pipeline.compile("button.module.css", ".btn { color: red }")

      assert result.code =~ "export default"
      assert result.css =~ "_btn_"
    end
  end
end
