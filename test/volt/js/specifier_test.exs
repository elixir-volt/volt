defmodule Volt.JS.SpecifierTest do
  use ExUnit.Case, async: true

  doctest Volt.JS.Specifier

  describe "split_query/1" do
    test "preserves package import specifiers" do
      assert Volt.JS.Specifier.split_query("#client/constants") == {"#client/constants", ""}
    end

    test "splits queries on package import specifiers" do
      assert Volt.JS.Specifier.split_query("#client/constants?raw") ==
               {"#client/constants", "raw"}
    end

    test "keeps URL-style behavior for non-package-import specifiers" do
      assert Volt.JS.Specifier.split_query("./style.css?inline") == {"./style.css", "inline"}
      assert Volt.JS.Specifier.split_query("./module.js#hash") == {"./module.js", ""}
    end
  end
end
