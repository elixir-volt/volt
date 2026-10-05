defmodule Volt.Plugin.VueTest do
  use ExUnit.Case, async: true

  test "template-only SFCs expose a default component" do
    assert {:ok, result} =
             Volt.Plugin.Vue.compile(
               "/fixtures/Only.vue",
               "<template><button>Widget</button></template>",
               []
             )

    assert result.code =~ "export default { render }"
  end

  describe "embedded_modules/3" do
    defp script_modules(source) do
      "Example.vue"
      |> Volt.Plugin.Vue.embedded_modules(source, [])
      |> Volt.Plugin.EmbeddedModule.normalize_all()
      |> Enum.filter(&(&1.type == :script))
      |> Enum.map(&{&1.extension, String.trim(&1.source)})
    end

    test "leaves out script blocks that are not JavaScript" do
      source = """
      <script setup lang="ts">
      const n: number = 1
      </script>

      <script lang="elixir">
      def total(%{items: items}), do: length(items)
      </script>

      <template><p>{{ n }}</p></template>
      """

      assert script_modules(source) == [{".ts", "const n: number = 1"}]
    end

    test "names script blocks by their JavaScript dialect" do
      for {lang, extension} <- [
            {"", ".js"},
            {~s( lang="js"), ".js"},
            {~s( lang="jsx"), ".jsx"},
            {~s( lang="ts"), ".ts"},
            {~s( lang="tsx"), ".tsx"}
          ] do
        source = "<script#{lang}>export default {}</script><template><p /></template>"

        assert script_modules(source) == [{extension, "export default {}"}]
      end
    end
  end

  test "script-bearing scoped components receive their CSS scope on the default export" do
    for script <- [
          "<script setup>defineProps(['label'])</script>",
          "<script>export default { props: ['label'] }</script>"
        ] do
      source =
        script <>
          "<template><button>{{ label }}</button></template><style scoped>button { color: red }</style>"

      assert {:ok, result} = Volt.Plugin.Vue.compile("/fixtures/Script.vue", source, [])
      scope = "data-v-" <> Vize.SFC.scope_id("/fixtures/Script.vue")
      assert result.code =~ "__scopeId = \"#{scope}\""
      assert result.css =~ scope
      assert {:ok, _} = OXC.parse(result.code, "component.js")
      assert is_nil(result.sourcemap)
    end
  end

  @tag :tmp_dir
  test "scope attachment does not capture module bindings and preserves component identity", %{
    tmp_dir: tmp
  } do
    file = "/fixtures/Shadow.vue"

    source = """
    <script>
    export const Object = {};
    export const component = { value: 42 };
    export default component;
    </script>
    <style scoped>p { color: red }</style>
    """

    assert {:ok, result} = Volt.Plugin.Vue.compile(file, source, [])
    File.write!(Path.join(tmp, "scoped.js"), result.code)

    File.write!(Path.join(tmp, "assertions.js"), """
    import scoped, { Object, component } from "./scoped.js";
    globalThis.observed = {
      scope: scoped.__scopeId,
      same: scoped === component,
      value: scoped.value,
      untouched: !Object.__scopeId
    };
    """)

    runtime = start_supervised!({QuickBEAM, script: Path.join(tmp, "assertions.js")})

    scope = "data-v-" <> Vize.SFC.scope_id(file)

    assert {:ok, %{"scope" => ^scope, "same" => true, "value" => 42, "untouched" => true}} =
             QuickBEAM.eval(runtime, "globalThis.observed")
  end

  test "template-only scoped CSS and component use the same scope identity" do
    file = "/fixtures/Scoped.vue"

    source =
      "<template><button>Widget</button></template><style scoped>button { color: red }</style>"

    assert {:ok, result} = Volt.Plugin.Vue.compile(file, source, [])
    scope = "data-v-" <> Vize.SFC.scope_id(file)
    assert result.code =~ scope
    assert result.css =~ scope
    assert result.code =~ "__scopeId"
  end
end
