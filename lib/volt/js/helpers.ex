defmodule Volt.JS.Helpers do
  @moduledoc false

  def ts_dir, do: Volt.JS.Asset.priv_dir()

  def run_npx(args) do
    case System.cmd("npx", ["--yes" | args], stderr_to_stdout: true, cd: System.tmp_dir!()) do
      {output, 0} ->
        if output != "", do: IO.write(output)

      {output, _code} ->
        IO.write(output)
        Mix.raise("#{hd(args)} failed")
    end
  end
end
