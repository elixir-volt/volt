defmodule Volt.HMR.Client do
  @moduledoc """
  Serves the HMR client JavaScript, compiled from TypeScript.
  """

  @doc "Returns the HMR client as compiled JavaScript."
  @spec js :: String.t()
  def js, do: Volt.JS.Asset.compiled!("hmr-client.ts")
end
