defmodule Volt.Test.SigilsTest do
  use ExUnit.Case, async: true

  import Volt.Test.Sigils

  test "returns JavaScript source" do
    assert ~JS"const value = 1" == "const value = 1"
  end

  test "does not interpolate uppercase fixture sigils" do
    assert ~TS"const #{name}: number = 1" == "const \#{name}: number = 1"
  end

  test "validates JS-like sigils with the v modifier" do
    assert ~TS"const value: number = 1"v == "const value: number = 1"
    assert ~JSX"const node = <div />"v == "const node = <div />"
    assert ~TSX"const node: JSX.Element = <div />"v == "const node: JSX.Element = <div />"

    assert_raise ArgumentError, ~r/invalid snippet\.ts source/, fn ->
      ~TS"const = ;"v
    end
  end

  test "provides CSS and HTML fixture sigils" do
    assert ~CSS".button { color: red }" == ".button { color: red }"
    assert ~HTML"<main>Hello</main>" == "<main>Hello</main>"
  end
end
