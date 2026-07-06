defmodule Volt.Client.BrowserTest do
  @moduledoc "Exercises browser-owned Volt client runtime behavior with Volt JS tests."

  use ExUnit.Case, async: false

  @moduletag :integration

  test "browser client runtime fixtures pass through Volt.Test.ExUnit" do
    modules =
      Volt.Test.ExUnit.install(
        root: "test/volt/client/fixtures",
        include: ["**/*.browser.test.ts"],
        browser: true
      )

    assert modules != []

    for module <- modules, test <- module.__ex_unit__().tests do
      assert :ok = apply(module, test.name, [%{}])
    end
  end
end
