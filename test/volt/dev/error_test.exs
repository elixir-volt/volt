defmodule Volt.Dev.ErrorTest do
  use ExUnit.Case, async: true

  alias Volt.Dev.Error

  @moduletag :tmp_dir

  test "locates diagnostics and frames the source line", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "app.ts")
    File.write!(path, "const a = 1\nconst b = 2\nconst = ;\nconst c = 3\nconst d = 4\n")
    {:error, diagnostics} = OXC.parse(File.read!(path), "app.ts")

    assert [%{file: file, line: 3, column: 7, message: message, frame: frame}] =
             Error.entries(diagnostics, file: path)

    assert file == Path.relative_to_cwd(path)
    assert message =~ "Unexpected token"

    assert frame == """
             1 | const a = 1
             2 | const b = 2
           > 3 | const = ;
               |       ^
             4 | const c = 3\
           """
  end

  test "highlights the frame with Lumis when a parser covers the language", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "app.ts")
    File.write!(path, "/* a\n   comment */\nconst a = 1 < 2\nconst = ;\n")
    {:error, diagnostics} = OXC.parse(File.read!(path), "app.ts")

    assert [%{frame_html: html}] = Error.entries(diagnostics, file: path)
    assert html =~ ~s(<span style="color:#ff6b9a">&gt; 4 | </span>)
    assert html =~ ~s(<span style="color:#6b5b8f">  3 | </span>)
    assert html =~ ~s(<span style="color: #8b949e;">   comment */</span>)
    assert html =~ "&lt;"
    refute html =~ "1 < 2"
    assert length(String.split(html, "\n")) == 5
  end

  test "keeps only the plain frame without a parser for the language", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "app.css")
    File.write!(path, ".a { color: red\n")

    assert [%{frame: "> 1 | .a { color: red" <> _, frame_html: nil}] =
             Error.entries(%{message: "x", position: {1, 2}}, file: path)
  end

  test "keeps a diagnostic's own file when it differs from the source path" do
    diagnostic = %{message: "boom", file: "other.ts", position: {2, 1}, details: "try this"}

    assert [%{file: "other.ts", line: 2, column: 1, hint: "try this", frame: nil}] =
             Error.entries([diagnostic], file: "app.ts")
  end

  test "describes messages, exceptions, and other terms" do
    assert [
             %{message: "plain", file: "app.ts", line: nil, frame: nil},
             %{message: "raised"},
             %{message: "{:unsupported, \".xyz\"}"}
           ] =
             Error.entries(["plain", RuntimeError.exception("raised"), {:unsupported, ".xyz"}],
               file: "app.ts"
             )
  end

  test "entries encode as JSON" do
    {:error, diagnostics} = OXC.parse("const = ;", "app.ts")
    assert {:ok, _json} = diagnostics |> Error.entries(file: "app.ts") |> Jason.encode()
  end
end
