defmodule Volt.PluginRunnerTest do
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

  defmodule PrePlugin do
    @behaviour Volt.Plugin
    def name, do: "pre"
    def enforce, do: :pre
    def transform(code, _path), do: {:ok, code <> "pre"}
  end

  defmodule NormalPlugin do
    @behaviour Volt.Plugin
    def name, do: "normal"
    def transform(code, _path), do: {:ok, code <> "normal"}
  end

  defmodule PostPlugin do
    @behaviour Volt.Plugin
    def name, do: "post"
    def enforce, do: :post
    def transform(code, _path), do: {:ok, code <> "post"}
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

  defmodule EmbeddedPlugin do
    @behaviour Volt.Plugin

    @impl true
    def name, do: "embedded"

    @impl true
    def embedded_modules(path, source, _opts) do
      if Path.extname(path) == ".box" do
        [
          %Volt.Plugin.EmbeddedModule{type: :script, extension: ".ts", source: source},
          {".css", ".box { color: red }"}
        ]
      end
    end
  end

  describe "transform/3" do
    test "pipes code through transform hooks" do
      result = Volt.PluginRunner.transform([UppercasePlugin], "hello", "test.js")
      assert result == "HELLO"
    end

    test "skips plugins without transform" do
      result = Volt.PluginRunner.transform([VirtualPlugin], "hello", "test.js")
      assert result == "hello"
    end

    test "orders transforms by enforce phase" do
      result =
        Volt.PluginRunner.transform([PostPlugin, NormalPlugin, PrePlugin], "", "test.js")

      assert result == "prenormalpost"
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

  describe "define/2" do
    test "collects plugin-provided defines" do
      defmodule DefinePlugin do
        @behaviour Volt.Plugin
        def name, do: "define"
        def define(mode), do: %{"import.meta.env.CUSTOM_MODE" => Jason.encode!(mode)}
      end

      assert Volt.PluginRunner.define([DefinePlugin], "production") == %{
               "__VUE_OPTIONS_API__" => "true",
               "__VUE_PROD_DEVTOOLS__" => "false",
               "__VUE_PROD_HYDRATION_MISMATCH_DETAILS__" => "false",
               "import.meta.env.CUSTOM_MODE" => ~s("production")
             }
    end

    test "passes tuple options to define callbacks" do
      defmodule ConfiguredDefinePlugin do
        @behaviour Volt.Plugin
        def name, do: "configured-define"
        def define(_mode, opts), do: Keyword.fetch!(opts, :define)
      end

      assert Volt.PluginRunner.define(
               [{ConfiguredDefinePlugin, define: %{"APP" => "true"}}],
               "test"
             )[
               "APP"
             ] == "true"
    end
  end

  describe "resolve/3" do
    test "resolves via plugin" do
      assert {:ok, "virtual:config"} =
               Volt.PluginRunner.resolve([VirtualPlugin], "virtual:config", nil)
    end

    test "returns nil when no plugin matches" do
      assert nil == Volt.PluginRunner.resolve([VirtualPlugin], "vue", nil)
    end
  end

  describe "load/2" do
    test "loads virtual module content" do
      assert {:ok, code} = Volt.PluginRunner.load([VirtualPlugin], "virtual:config")
      assert code =~ "debug"
    end

    test "returns nil for unhandled paths" do
      assert nil == Volt.PluginRunner.load([VirtualPlugin], "other.js")
    end
  end

  describe "embedded_modules/4" do
    test "normalizes plugin-returned embedded modules" do
      [script, style] =
        Volt.PluginRunner.embedded_modules([EmbeddedPlugin], "card.box", "export {}", [])

      assert %Volt.Plugin.EmbeddedModule{type: :script, index: 0, extension: ".ts"} = script
      assert %Volt.Plugin.EmbeddedModule{type: :style, index: 1, extension: ".css"} = style
    end

    test "loads embedded modules by query id" do
      path = Path.expand("volt-plugin-runner-card.box", System.tmp_dir!())
      File.write!(path, "export const value: number = 1")

      id =
        Volt.Plugin.EmbeddedModule.id(path, %Volt.Plugin.EmbeddedModule{
          type: :script,
          index: 0,
          extension: ".ts",
          source: ""
        })

      assert {:ok, module, ^path} = Volt.PluginRunner.embedded_module([EmbeddedPlugin], id)
      assert module.source =~ "value: number"

      File.rm(path)
    end
  end

  describe "extensions/2" do
    test "configured built-in plugins replace defaults instead of being dropped" do
      plugins = Volt.PluginRunner.plugins([{Volt.Plugin.Svelte, marker: true}])

      refute Volt.Plugin.Svelte in plugins
      assert {Volt.Plugin.Svelte, marker: true} in plugins
      assert Volt.Plugin.Vue in plugins
      assert Volt.Plugin.React in plugins
    end

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
end
