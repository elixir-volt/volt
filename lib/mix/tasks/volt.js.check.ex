defmodule Mix.Tasks.Volt.Js.Check do
  use Mix.Task

  @shortdoc "Lint and format-check Volt TypeScript assets"

  @moduledoc """
  Run oxfmt format check and oxlint on Volt's TypeScript assets.

      mix volt.js.check

  Requires `npx` (Node.js) to be available on PATH.
  """

  @impl true
  def run(_args) do
    Volt.JsHelpers.run_npx(["oxfmt", "--check", Volt.JsHelpers.ts_dir()])
    Volt.JsHelpers.run_npx(["oxlint", Volt.JsHelpers.ts_dir()])
  end
end
