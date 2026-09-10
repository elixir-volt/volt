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
