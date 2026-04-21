defmodule Volt.JS.Helpers do
  @moduledoc false

  @extensions ~w(.js .ts .jsx .tsx)

  def assets_dir do
    Volt.Config.build().root
  end

  def discover_files(dir) do
    Path.wildcard("#{dir}/**/*")
    |> Enum.filter(&(Path.extname(&1) in @extensions))
    |> Enum.reject(&String.contains?(&1, "node_modules"))
    |> Enum.sort()
  end
end
