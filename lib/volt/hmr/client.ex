defmodule Volt.HMR.Client do
  @moduledoc """
  Serves the HMR client JavaScript, compiled from TypeScript.
  """

  @source_path Path.expand("../../../priv/ts/hmr-client.ts", __DIR__)

  @doc "Returns the HMR client as compiled JavaScript."
  @spec js :: String.t()
  def js do
    case compiled() do
      {:ok, code} -> code
      {:error, _} -> source()
    end
  end

  defp compiled do
    case :persistent_term.get({__MODULE__, :compiled}, nil) do
      nil ->
        result = OXC.transform(source(), "hmr-client.ts", sourcemap: false)

        case result do
          {:ok, %{code: code}} ->
            :persistent_term.put({__MODULE__, :compiled}, code)
            {:ok, code}

          {:ok, code} when is_binary(code) ->
            :persistent_term.put({__MODULE__, :compiled}, code)
            {:ok, code}

          error ->
            error
        end

      code ->
        {:ok, code}
    end
  end

  defp source, do: File.read!(@source_path)
end
