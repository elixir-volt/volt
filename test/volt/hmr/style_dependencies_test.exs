defmodule Volt.HMR.StyleDependenciesTest do
  use ExUnit.Case, async: false

  @root Path.expand("../fixtures/style_dependencies", __DIR__)

  setup do
    Volt.HMR.StyleGraph.clear()
    File.rm_rf!(@root)
    File.mkdir_p!(@root)

    on_exit(fn -> File.rm_rf!(@root) end)
    :ok
  end

  test "tracks dependencies from physical CSS source" do
    css_path = Path.join(@root, "app.css")
    logo_path = Path.join(@root, "logo.svg")

    File.write!(logo_path, "<svg></svg>")

    Volt.HMR.StyleDependencies.update_from_compile(
      css_path,
      ".logo { background: url('./logo.svg') }",
      %Volt.Pipeline.Result{type: :css, code: ".ignored { color: red }"}
    )

    assert Volt.HMR.StyleGraph.dependencies_of(css_path) == [logo_path]
    assert Volt.HMR.StyleGraph.dependents(logo_path) == [css_path]
  end

  test "tracks dependencies from emitted CSS for non-CSS source files" do
    vue_path = Path.join(@root, "App.vue")
    logo_path = Path.join(@root, "logo.svg")

    File.write!(logo_path, "<svg></svg>")

    Volt.HMR.StyleDependencies.update_from_compile(
      vue_path,
      "<template><div /></template>",
      %Volt.Pipeline.Result{
        code: "export default {}",
        css: ".logo { background: url('./logo.svg') }"
      }
    )

    assert Volt.HMR.StyleGraph.dependencies_of(vue_path) == [logo_path]
    assert Volt.HMR.StyleGraph.dependents(logo_path) == [vue_path]
  end

  test "removes dependencies when non-CSS output has no emitted CSS" do
    vue_path = Path.join(@root, "App.vue")
    logo_path = Path.join(@root, "logo.svg")

    File.write!(logo_path, "<svg></svg>")

    Volt.HMR.StyleDependencies.update_from_compile(
      vue_path,
      "<template><div /></template>",
      %Volt.Pipeline.Result{
        code: "export default {}",
        css: ".logo { background: url('./logo.svg') }"
      }
    )

    assert Volt.HMR.StyleGraph.dependents(logo_path) == [vue_path]

    Volt.HMR.StyleDependencies.update_from_compile(
      vue_path,
      "<template><div /></template>",
      %Volt.Pipeline.Result{code: "export default {}", css: nil}
    )

    assert Volt.HMR.StyleGraph.dependencies_of(vue_path) == []
    assert Volt.HMR.StyleGraph.dependents(logo_path) == []
  end
end
