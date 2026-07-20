defmodule Volt.Builder.NamingTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.Naming

  test "replaces characters that are invalid in Windows filenames" do
    assert Naming.file_path("virtual:volt/test?<entry>|.js") ==
             "virtual_volt/test__entry__.js"
  end

  test "normalizes separators, trailing dots, and reserved Windows names" do
    assert Naming.file_path("scope\\CON.js/trailing. ") == "scope/_CON.js/trailing"
  end

  test "derives filesystem-safe entry names" do
    assert Naming.entry_name("virtual:volt/test.ts") == "test"
    assert Naming.entry_name("ignored.ts", "CON:entry") == "CON_entry"
  end

  test "derives module labels and JavaScript wrapper extensions" do
    root = Path.join(System.tmp_dir!(), "volt-naming-root")

    assert Naming.module_label(Path.join(root, "src/data.json"), root) == "src/data.json.js"

    assert Naming.module_label(Path.join(root, "src/style.css") <> "?raw", root) ==
             "src/style.css.raw.js"

    assert Naming.module_label(Path.join(root, "node_modules/pkg/index.js"), root) ==
             "pkg/index.js"
  end

  test "adds stable unique suffixes before file extensions" do
    used = MapSet.new(["src/index.js"])
    unique = Naming.unique("src/index.js", "virtual:first", used)

    assert unique =~ ~r|^src/index-[0-9a-f]{10}\.js$|
    assert Naming.unique("src/index.js", "virtual:first", used) == unique
    assert Naming.unique("src/other.js", "virtual:other", used) == "src/other.js"
  end

  test "increments a stable suffix when the digest candidate is also used" do
    first = Naming.unique("entry", "virtual:entry", MapSet.new(["entry"]))
    used = MapSet.new(["entry", first])

    assert Naming.unique("entry", "virtual:entry", used) == first <> "-2"
  end
end
