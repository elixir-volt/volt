defmodule Volt.PluginTest do
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

  defmodule VirtualPlugin do
    @behaviour Volt.Plugin

    @impl true
    def name, do: "virtual"

    @impl true
    def resolve("virtual:config", _importer), do: {:ok, "virtual:config"}
    def resolve(_, _), do: nil

    @impl true
    def load("virtual:config"), do: {:ok, "export default {debug: true};\n"}
    def load(_), do: nil
  end

  describe "PluginRunner.transform/3" do
    test "pipes code through transform hooks" do
      result = Volt.PluginRunner.transform([UppercasePlugin], "hello", "test.js")
      assert result == "HELLO"
    end

    test "skips plugins without transform" do
      result = Volt.PluginRunner.transform([VirtualPlugin], "hello", "test.js")
      assert result == "hello"
    end

    test "chains multiple transforms" do
      defmodule PrefixPlugin do
        @behaviour Volt.Plugin
        def name, do: "prefix"
        def transform(code, _path), do: {:ok, "/* volt */\n" <> code}
      end

      result =
        Volt.PluginRunner.transform([PrefixPlugin, UppercasePlugin], "hello", "test.js")

      assert result == "/* VOLT */\nHELLO"
    end
  end

  describe "PluginRunner.resolve/3" do
    test "resolves via plugin" do
      assert {:ok, "virtual:config"} =
               Volt.PluginRunner.resolve([VirtualPlugin], "virtual:config", nil)
    end

    test "returns nil when no plugin matches" do
      assert nil == Volt.PluginRunner.resolve([VirtualPlugin], "vue", nil)
    end
  end

  describe "PluginRunner.load/2" do
    test "loads virtual module content" do
      assert {:ok, code} = Volt.PluginRunner.load([VirtualPlugin], "virtual:config")
      assert code =~ "debug"
    end

    test "returns nil for unhandled paths" do
      assert nil == Volt.PluginRunner.load([VirtualPlugin], "other.js")
    end
  end

  describe "PluginRunner.extensions/2" do
    test "passes tuple options to plugins with arity-aware callbacks" do
      defmodule ConfiguredExtensionsPlugin do
        @behaviour Volt.Plugin
        def name, do: "configured-extensions"
        def extensions(:compile, opts), do: Keyword.fetch!(opts, :extensions)
        def extensions(_, _opts), do: []
      end

      assert ".widget" in Volt.PluginRunner.extensions(
               [{ConfiguredExtensionsPlugin, extensions: [".widget"]}],
               :compile
             )
    end

    test "includes built-in Vue extensions and custom plugin extensions" do
      defmodule SfcPlugin do
        @behaviour Volt.Plugin
        def name, do: "sfc"
        def extensions(:compile), do: [".sfc"]
        def extensions(_), do: []
      end

      assert ".vue" in Volt.PluginRunner.extensions([], :compile)
      assert ".svelte" in Volt.PluginRunner.extensions([], :compile)
      assert ".sfc" in Volt.PluginRunner.extensions([SfcPlugin], :compile)
    end
  end

  describe "Volt.Plugin.Svelte" do
    @tag :integration
    test "accepts plugin compiler options" do
      assert {:ok, %{code: code, warnings: warnings}} =
               Volt.Plugin.Svelte.compile("App.svelte", "<h1>Hello</h1>", [], generate: :server)

      assert code =~ "svelte/internal/server"
      assert is_list(warnings)
    end

    test "extracts imports from script blocks" do
      source = """
      <script module>
        import config from './config'
      </script>
      <script lang="ts">
        import Child from './Child.svelte'
        import { format } from '../format'
      </script>
      <h1>{format(config.title)}</h1>
      """

      assert {:ok, %{imports: imports, workers: []}} =
               Volt.Plugin.Svelte.extract_imports("App.svelte", source, [])

      assert {:static, "./config"} in imports
      assert {:static, "./Child.svelte"} in imports
      assert {:static, "../format"} in imports
    end
  end

  describe "Pipeline integration" do
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
end
