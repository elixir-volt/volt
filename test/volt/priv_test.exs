defmodule Volt.PrivTest do
  use ExUnit.Case, async: true

  @support_modules {:volt, "ts"}

  test "reads files from a priv subdirectory" do
    code = Volt.Priv.read!(@support_modules, "dev/hmr-client.ts")

    assert code =~ "const proto"
  end

  test "reads files directly from an application priv directory" do
    code = Volt.Priv.read!(:volt, "ts/dev/hmr-client.ts")

    assert code =~ "const proto"
  end

  test "emits browser JavaScript from TypeScript support modules" do
    code = Volt.Priv.js!(@support_modules, "dev/hmr-client.ts")

    assert code =~ "const proto"
    refute code =~ "type "
  end

  test "binds JavaScript literals and rewrites support imports" do
    code =
      Volt.Priv.js!(@support_modules, "dev/hmr-preamble.ts", [mod_url: "/assets/app.ts"],
        rewrite_specifiers: %{"./hmr-client" => "/@volt/client.js"}
      )

    assert code =~ ~s(from "/@volt/client.js")
    assert code =~ "createHotContext(\"/assets/app.ts\")"
    refute code =~ "./hmr-client"
    refute code =~ "$mod_url"
  end

  test "rejects paths outside priv" do
    assert_raise ArgumentError, fn -> Volt.Priv.path(@support_modules, "../secret.ts") end
    assert_raise ArgumentError, fn -> Volt.Priv.path(@support_modules, "/tmp/secret.ts") end
  end
end
