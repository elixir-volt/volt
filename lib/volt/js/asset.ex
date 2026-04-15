defmodule Volt.JS.Asset do
  @moduledoc false

  @base_dir Path.expand("../../../priv/ts", __DIR__)

  @spec read!(String.t()) :: String.t()
  def read!(filename) do
    filename
    |> path_for()
    |> File.read!()
  end

  @doc """
  Read a TypeScript asset, compile to JavaScript, and cache in persistent_term.

  Returns compiled JS on subsequent calls without recompilation.
  """
  @spec compiled!(String.t()) :: String.t()
  def compiled!(filename) do
    key = {__MODULE__, :compiled, filename}

    case :persistent_term.get(key, nil) do
      nil ->
        code = read!(filename) |> compile_ts(filename)
        :persistent_term.put(key, code)
        code

      code ->
        code
    end
  end

  @spec path_for(String.t()) :: String.t()
  def path_for(filename), do: Path.join(@base_dir, filename)

  # OXC.transform returns a plain string with sourcemap: false,
  # or %{code: string, sourcemap: string} with sourcemap: true.
  defp compile_ts(source, filename) do
    case OXC.transform(source, filename, sourcemap: false) do
      {:ok, code} when is_binary(code) -> code
      {:ok, %{code: code}} -> code
      _ -> source
    end
  end
end
