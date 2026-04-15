defmodule Mix.Tasks.Volt.Js.Fmt do
  use Mix.Task

  @shortdoc "Format Volt TypeScript assets"

  @moduledoc """
  Format Volt's TypeScript assets with oxfmt.

      mix volt.js.fmt

  Requires `npx` (Node.js) to be available on PATH.
  """

  @impl true
  def run(_args) do
    Volt.JS.Helpers.run_npx(["oxfmt", "--write", Volt.JS.Helpers.ts_dir()])
  end
end
