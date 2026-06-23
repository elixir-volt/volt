defmodule Volt.HMR.StyleGraphTest do
  use ExUnit.Case, async: false

  setup do
    Volt.HMR.StyleGraph.clear()
    :ok
  end

  test "tracks direct imports and transitive dependents" do
    app = "/app/app.css"
    theme = "/app/theme.css"
    tokens = "/app/tokens.css"

    Volt.HMR.StyleGraph.update(app, [theme])
    Volt.HMR.StyleGraph.update(theme, [tokens])

    assert Volt.HMR.StyleGraph.imports_of(app) == [theme]
    assert Volt.HMR.StyleGraph.dependents(tokens) |> Enum.sort() == [app, theme]
  end

  test "updates importer links when imports change" do
    app = "/app/app.css"
    old_tokens = "/app/old.css"
    new_tokens = "/app/new.css"

    Volt.HMR.StyleGraph.update(app, [old_tokens])
    assert Volt.HMR.StyleGraph.dependents(old_tokens) == [app]

    Volt.HMR.StyleGraph.update(app, [new_tokens])

    assert Volt.HMR.StyleGraph.dependents(old_tokens) == []
    assert Volt.HMR.StyleGraph.dependents(new_tokens) == [app]
  end

  test "removes stylesheet from graph" do
    app = "/app/app.css"
    tokens = "/app/tokens.css"

    Volt.HMR.StyleGraph.update(app, [tokens])
    Volt.HMR.StyleGraph.remove(app)

    assert Volt.HMR.StyleGraph.imports_of(app) == []
    assert Volt.HMR.StyleGraph.dependents(tokens) == []
  end
end
