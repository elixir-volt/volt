defmodule Volt.Builder.BundleResult do
  @moduledoc "Extract code and sourcemap from OXC bundle results."

  @spec extract(String.t() | map()) :: {String.t(), String.t() | nil}
  def extract(result) when is_binary(result), do: {result, nil}
  def extract(%{code: code, sourcemap: map}), do: {code, map}

  @spec code(String.t() | map()) :: String.t()
  def code(result) do
    result
    |> extract()
    |> elem(0)
  end
end
