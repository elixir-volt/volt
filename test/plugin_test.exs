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

  describe "Pipeline integration" do
    test "plugins receive compiled output" do
      {:ok, result} =
        Volt.Pipeline.compile("app.ts", "const x: number = 42", plugins: [UppercasePlugin])

      assert result.code == String.upcase(result.code)
    end
  end
end
