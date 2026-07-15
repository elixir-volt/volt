defmodule Volt.PrivTest do
  use ExUnit.Case, async: true

  @support_modules {:volt, "ts"}

  test "reads files from a priv subdirectory" do
    code = Volt.Priv.read!(@support_modules, "client/hmr.ts")

    assert code =~ "const proto"
  end

  test "reads files directly from an application priv directory" do
    code = Volt.Priv.read!(:volt, "ts/client/hmr.ts")

    assert code =~ "const proto"
  end

  test "renders TypeScript without compiling it" do
    code = Volt.Priv.render!(@support_modules, "test/browser.ts")

    assert code =~ "type BrowserPayload"
    assert code =~ "src: string"
  end

  test "emits browser JavaScript from TypeScript support modules" do
    code = Volt.Priv.js!(@support_modules, "client/hmr.ts")

    assert code =~ "const proto"
    refute code =~ "type "
  end

  test "invalidates cached support modules when their source changes" do
    relative = "test/cache-#{System.unique_integer([:positive])}.ts"
    path = Volt.Priv.path(@support_modules, relative)
    on_exit(fn -> File.rm(path) end)

    File.write!(path, "export const value = 1;")
    assert Volt.Priv.js!(@support_modules, relative) =~ "value = 1"

    File.write!(path, "export const value = 2;")
    assert Volt.Priv.js!(@support_modules, relative) =~ "value = 2"
  end

  test "binds JavaScript literals and rewrites support imports" do
    code =
      Volt.Priv.js!(
        @support_modules,
        "client/templates/hmr-preamble.ts",
        [mod_url: "/assets/app.ts"],
        rewrite_specifiers: %{"../hmr" => "/@volt/client.js"}
      )

    assert code =~ ~s(from "/@volt/client.js")
    assert code =~ "createHotContext(\"/assets/app.ts\")"
    refute code =~ "../hmr"
    refute code =~ "$mod_url"
  end

  test "splices multiple statements into support modules" do
    code =
      Volt.Priv.js!(@support_modules, "test/entry.ts", [],
        splices: [imports: ~s|import "./setup.ts"; import "./test.ts";|]
      )

    assert code =~ ~s(import "./setup.ts")
    assert code =~ ~s(import "./test.ts")
    refute code =~ "$imports"
  end

  test "rejects paths outside priv" do
    assert_raise ArgumentError, fn -> Volt.Priv.path(@support_modules, "../secret.ts") end
    assert_raise ArgumentError, fn -> Volt.Priv.path(@support_modules, "/tmp/secret.ts") end
  end
end
