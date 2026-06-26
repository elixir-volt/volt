defmodule Volt.Plugin.EmbeddedModuleTest do
  use ExUnit.Case, async: true

  alias Volt.Plugin.EmbeddedModule

  test "builds and parses query ids derived from parent files" do
    module = %EmbeddedModule{type: :style, index: 1, extension: ".css", source: ".x{}"}
    id = EmbeddedModule.id("/site/src/Card.box", module)

    assert id == "/site/src/Card.box?index=1&type=style&volt-embedded=1"

    assert {:ok, %EmbeddedModule.ID{parent: "/site/src/Card.box", type: :style, index: 1}} =
             EmbeddedModule.parse_id(id)

    assert EmbeddedModule.parent_path(id) == "/site/src/Card.box"
  end

  test "builds relative import specifiers for parent-embedded imports" do
    module = %EmbeddedModule{type: :script, index: 0, extension: ".ts", source: ""}

    assert EmbeddedModule.specifier("/site/src/Card.box", module) ==
             "./Card.box?index=0&type=script&volt-embedded=1"
  end

  test "normalizes legacy tuple modules" do
    assert %EmbeddedModule{type: :script, index: 2, extension: ".ts", source: "export {}"} =
             EmbeddedModule.normalize({".ts", "export {}"}, 2)

    assert %EmbeddedModule{type: :style, index: 3, extension: ".css", source: ".x{}"} =
             EmbeddedModule.normalize({".css", ".x{}"}, 3)
  end
end
