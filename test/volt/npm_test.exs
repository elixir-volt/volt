defmodule Volt.NPMTest do
  use ExUnit.Case, async: true

  test "install!/2 rejects invalid package entries before installation" do
    assert_raise ArgumentError, ~r/non-empty string names and versions/, fn ->
      Volt.NPM.install!(%{"package" => ""})
    end
  end
end
