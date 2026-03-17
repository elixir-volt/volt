defmodule Volt.Format do
  @moduledoc false

  def format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  def file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> 0
    end
  end

  def content_hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  def gzip_size(content) when is_binary(content) do
    :zlib.gzip(content) |> byte_size()
  end

  def format_with_gzip(content) when is_binary(content) do
    raw = byte_size(content)
    gz = gzip_size(content)
    "#{format_size(raw)} (gzip: #{format_size(gz)})"
  end
end
