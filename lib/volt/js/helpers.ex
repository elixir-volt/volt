defmodule Volt.JS.Helpers do
  @moduledoc false

  def ts_dir, do: Path.join(File.cwd!(), "priv/ts")
end
