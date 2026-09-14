defmodule Volt.Config.TailwindTest do
  use ExUnit.Case, async: true

  test "normalizes disabled and default-enabled configuration" do
    for value <- [false, nil, true] do
      assert %Volt.Config.Tailwind{sources: [], css: nil} = Volt.Config.Tailwind.new(value)
    end

    refute Volt.Config.Tailwind.enabled?(false)
    refute Volt.Config.Tailwind.enabled?(nil)
    assert Volt.Config.Tailwind.enabled?(true)
  end

  test "normalizes a configured root" do
    root =
      Volt.Config.Tailwind.new(
        css: "assets/styles.css",
        name: "site",
        dev_url: "/custom/site.css",
        sources: [%{base: "lib", pattern: "**/*.heex"}]
      )

    assert root.css == Path.expand("assets/styles.css")
    assert root.name == "site"
    assert root.dev_url == "/custom/site.css"
    assert root.sources == [%{base: "lib", pattern: "**/*.heex"}]
  end

  test "derives identity from the CSS input" do
    root = Volt.Config.Tailwind.new(css: "assets/styles.css")

    assert root.name == "styles"
    assert root.dev_url == "/assets/css/styles.css"
  end

  test "supports Tailwind defaults without a CSS input" do
    root = Volt.Config.Tailwind.new([])

    assert root.css == nil
    assert root.name == "app"
    assert root.dev_url == "/assets/css/app.css"
  end
end
