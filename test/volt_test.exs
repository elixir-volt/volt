defmodule VoltTest do
  use ExUnit.Case
  doctest Volt

  test "greets the world" do
    assert Volt.hello() == :world
  end
end
