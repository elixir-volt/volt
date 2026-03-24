defmodule Volt.HMR.Client do
  @moduledoc """
  Serves the HMR client JavaScript.
  """

  @doc "Returns the HMR client JavaScript source."
  @spec js :: String.t()
  def js, do: Volt.JSAsset.read!("hmr-client.ts")
end
