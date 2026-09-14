defmodule Volt.HMR.StyleGraphTest do
  use ExUnit.Case, async: false

  setup do
    Volt.HMR.StyleGraph.clear()
    :ok
  end

  test "transitive edges and cleanup remain inside their session" do
    alias Volt.HMR.StyleGraph
    StyleGraph.update("/app.css", ["/theme.css"], :a)
    StyleGraph.update("/theme.css", ["/tokens.css"], :a)
    StyleGraph.update("/app.css", ["/other.css"], :b)
    assert Enum.sort(StyleGraph.dependents("/tokens.css", :a)) == ["/app.css", "/theme.css"]
    assert StyleGraph.dependents("/tokens.css", :b) == []
    assert StyleGraph.dependents("/tokens.css") == []
    StyleGraph.clear_session(:a)
    assert StyleGraph.dependencies_of("/app.css", :a) == []
    assert StyleGraph.dependents("/other.css", :b) == ["/app.css"]
  end

  test "tracks direct dependencies and transitive dependents" do
    app = "/app/app.css"
    theme = "/app/theme.css"
    tokens = "/app/tokens.css"

    Volt.HMR.StyleGraph.update(app, [theme])
    Volt.HMR.StyleGraph.update(theme, [tokens])

    assert Volt.HMR.StyleGraph.dependencies_of(app) == [theme]
    assert Volt.HMR.StyleGraph.dependents(tokens) |> Enum.sort() == [app, theme]
  end

  test "updates dependent links when dependencies change" do
    app = "/app/app.css"
    old_tokens = "/app/old.css"
    new_tokens = "/app/new.css"

    Volt.HMR.StyleGraph.update(app, [old_tokens])
    assert Volt.HMR.StyleGraph.dependents(old_tokens) == [app]

    Volt.HMR.StyleGraph.update(app, [new_tokens])

    assert Volt.HMR.StyleGraph.dependents(old_tokens) == []
    assert Volt.HMR.StyleGraph.dependents(new_tokens) == [app]
  end

  test "handles import cycles without returning the changed stylesheet as its own dependent" do
    app = "/app/app.css"
    theme = "/app/theme.css"
    tokens = "/app/tokens.css"

    Volt.HMR.StyleGraph.update(app, [theme])
    Volt.HMR.StyleGraph.update(theme, [tokens])
    Volt.HMR.StyleGraph.update(tokens, [app])

    assert Volt.HMR.StyleGraph.dependents(tokens) |> Enum.sort() == [app, theme]
  end

  test "removes stylesheet from graph" do
    app = "/app/app.css"
    tokens = "/app/tokens.css"

    Volt.HMR.StyleGraph.update(app, [tokens])
    Volt.HMR.StyleGraph.remove(app)

    assert Volt.HMR.StyleGraph.dependencies_of(app) == []
    assert Volt.HMR.StyleGraph.dependents(tokens) == []
  end
end
