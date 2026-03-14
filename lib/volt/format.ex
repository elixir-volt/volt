defmodule Volt.Format do
  @moduledoc false

  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"
end
