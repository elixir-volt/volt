defmodule Volt.JS.Helpers do
  @moduledoc false

  def ts_dir, do: Path.join(File.cwd!(), "priv/ts")

  def run_npx(args) do
    case System.cmd("npx", ["--yes" | args], stderr_to_stdout: true, cd: File.cwd!()) do
      {output, 0} ->
        if output != "", do: IO.write(output)

      {output, _code} ->
        IO.write(output)
        Mix.raise("#{hd(args)} failed")
    end
  end
end
