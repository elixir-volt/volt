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
    run_npx(["oxfmt", "--check", ts_dir()])
    run_npx(["oxlint", ts_dir()])
  end

  defp run_npx(args) do
    case System.cmd("npx", ["--yes" | args], stderr_to_stdout: true, cd: System.tmp_dir!()) do
      {output, 0} ->
        if output != "", do: IO.write(output)

      {output, _code} ->
        IO.write(output)
        Mix.raise("#{hd(args)} failed")
    end
  end

  defp ts_dir, do: Path.expand("priv/ts")
end
