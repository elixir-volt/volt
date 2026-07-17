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
end
