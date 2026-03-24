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
    run_npx(["oxfmt", "--write", ts_dir()])
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
