defmodule Volt.Builder.ArtifactTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.Artifact

  test "asset identity is derived from content and preserves the extension" do
    content = <<0, 255, 42>>
    hash = Volt.Builder.Naming.hash(content)

    assert Artifact.asset("/source/fonts/site.woff2", content) ==
             %Artifact{file: "site-#{hash}.woff2", content: content}

    assert Artifact.asset("/another/site.woff2", content) ==
             Artifact.asset("/source/fonts/site.woff2", content)

    refute Artifact.asset("site.woff2", content).file ==
             Artifact.asset("site.woff2", content <> <<1>>).file
  end

  test "prepares JavaScript and its sourcemap without filesystem output" do
    assert Artifact.javascript("app.js", "run();", "{}") == [
             %Artifact{file: "app.js", content: "run();\n//# sourceMappingURL=app.js.map\n"},
             %Artifact{file: "app.js.map", content: "{}"}
           ]
  end

  test "hidden sourcemaps are emitted without a reference" do
    assert Artifact.javascript("app.js", "run();", "{}", hidden: true) == [
             %Artifact{file: "app.js", content: "run();"},
             %Artifact{file: "app.js.map", content: "{}"}
           ]
  end

  test "JavaScript without a sourcemap produces only one artifact" do
    assert Artifact.javascript("app.js", "run();", nil) == [
             %Artifact{file: "app.js", content: "run();"}
           ]
  end
end
