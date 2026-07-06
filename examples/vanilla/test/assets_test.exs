defmodule VanillaExample.AssetsTest do
  @moduledoc "Runs the example application's Volt JavaScript tests through ExUnit."

  use ExUnit.Case, async: true

  @js_test_modules Volt.Test.ExUnit.install(root: "test/assets", include: ["**/*.test.ts"])

  test "JavaScript asset tests are registered as ExUnit tests" do
    assert @js_test_modules |> List.wrap() |> length() > 0
  end
end
