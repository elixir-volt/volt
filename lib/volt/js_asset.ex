defmodule Volt.JSAsset do
  @moduledoc false

  @base_dir Path.expand("../../priv/ts", __DIR__)

  @spec read!(String.t()) :: String.t()
  def read!(filename) do
    filename
    |> path_for()
    |> File.read!()
  end

  @spec path_for(String.t()) :: String.t()
  def path_for(filename), do: Path.join(@base_dir, filename)
end
