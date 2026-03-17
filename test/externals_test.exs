defmodule Volt.Builder.ExternalsTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.Externals

  describe "collect_imports/2" do
    test "extracts named imports from external specifiers" do
      js_files = [
        {"app.js", "import { ref, computed } from 'vue'\nconsole.log(ref(1))"}
      ]

      result = Externals.collect_imports(js_files, MapSet.new(["vue"]))
      assert Map.has_key?(result, "vue")
      assert {:named, "ref"} in result["vue"]
      assert {:named, "computed"} in result["vue"]
    end

    test "extracts default imports" do
      js_files = [
        {"app.js", "import Vue from 'vue'\nVue.createApp()"}
      ]

      result = Externals.collect_imports(js_files, MapSet.new(["vue"]))
      assert {:default, "Vue"} in result["vue"]
    end

    test "ignores non-external imports" do
      js_files = [
        {"app.js", "import { ref } from 'vue'\nimport { foo } from './utils'"}
      ]

      result = Externals.collect_imports(js_files, MapSet.new(["vue"]))
      assert Map.has_key?(result, "vue")
      refute Map.has_key?(result, "./utils")
    end

    test "merges imports from multiple files" do
      js_files = [
        {"a.js", "import { ref } from 'vue'"},
        {"b.js", "import { computed } from 'vue'"}
      ]

      result = Externals.collect_imports(js_files, MapSet.new(["vue"]))
      assert {:named, "ref"} in result["vue"]
      assert {:named, "computed"} in result["vue"]
    end
  end

  describe "generate_preamble/2" do
    test "generates destructuring for named imports" do
      imports = %{"vue" => [{:named, "ref"}, {:named, "computed"}]}
      globals = %{"vue" => "Vue"}

      preamble = Externals.generate_preamble(imports, globals)
      assert preamble =~ "const { ref, computed } = Vue;"
    end

    test "generates default import access" do
      imports = %{"vue" => [{:default, "Vue"}]}
      globals = %{"vue" => "VueLib"}

      preamble = Externals.generate_preamble(imports, globals)
      assert preamble =~ "const Vue = VueLib.default;"
    end

    test "handles mixed named and default imports" do
      imports = %{"vue" => [{:named, "ref"}, {:default, "Vue"}]}
      globals = %{"vue" => "VueGlobal"}

      preamble = Externals.generate_preamble(imports, globals)
      assert preamble =~ "const { ref } = VueGlobal;"
      assert preamble =~ "const Vue = VueGlobal.default;"
    end

    test "auto-derives global name when not in map" do
      imports = %{"reka-ui" => [{:named, "Button"}]}
      globals = %{}

      preamble = Externals.generate_preamble(imports, globals)
      assert preamble =~ "RekaUi"
    end
  end
end
