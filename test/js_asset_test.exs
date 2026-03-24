defmodule Volt.JSAssetTest do
  use ExUnit.Case, async: true

  test "reads TypeScript assets from priv/ts" do
    code = Volt.JSAsset.read!("hmr-client.ts")
    assert code =~ "const proto"
  end
end
