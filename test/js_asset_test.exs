defmodule Volt.JS.AssetTest do
  use ExUnit.Case, async: true

  test "reads TypeScript assets from priv/ts" do
    code = Volt.JS.Asset.read!("hmr-client.ts")
    assert code =~ "const proto"
  end
end
