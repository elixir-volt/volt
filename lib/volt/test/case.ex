defmodule Volt.Test.Case do
  @moduledoc """
  ExUnit case template for inline Volt JavaScript and TypeScript assertions.

  `use Volt.Test.Case` imports `Volt.Test.Assertions` and `Volt.Test.Sigils` so
  tests can run small JavaScript or TypeScript snippets from ordinary ExUnit
  test modules.
  """

  use ExUnit.CaseTemplate

  using opts do
    browser? = Keyword.get(opts, :browser, false)

    quote do
      import ExUnit.Assertions, except: [assert: 1, assert: 2]
      import Volt.Test.Assertions
      import Volt.Test.Sigils

      if unquote(browser?) do
        @moduletag browser_js: true
      end

      @volt_test_config unquote(opts)
    end
  end
end
