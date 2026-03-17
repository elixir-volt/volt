defmodule Volt.Format do
  @moduledoc false

  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  def gzip_size(content) when is_binary(content) do
    :zlib.gzip(content) |> byte_size()
  end

  def format_with_gzip(content) when is_binary(content) do
    raw = byte_size(content)
    gz = gzip_size(content)
    "#{format_size(raw)} (gzip: #{format_size(gz)})"
  end
end
