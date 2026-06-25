defmodule Volt.MIME do
  @moduledoc """
  Central MIME/content-type helpers used by Volt.

  Most file extension lookups delegate to the `MIME` package. Volt keeps a
  small amount of policy here for browser module responses and asset
  classification so callers do not need to repeat content-type literals.
  """

  @javascript "application/javascript"
  @css "text/css"
  @octet_stream "application/octet-stream"

  @asset_exts MapSet.new(~w[
    .svg .png .jpg .jpeg .gif .webp .avif .ico
    .woff .woff2 .ttf .eot .otf
    .mp4 .webm .ogg .mp3 .wav
    .pdf .wasm .txt
  ])

  @overrides %{
    ".ico" => "image/x-icon",
    ".ogg" => "audio/ogg"
  }

  @doc "JavaScript module content type used by Volt responses."
  @spec javascript() :: String.t()
  def javascript, do: @javascript

  @doc "CSS content type used by Volt responses."
  @spec css() :: String.t()
  def css, do: @css

  @doc "Fallback binary content type."
  @spec octet_stream() :: String.t()
  def octet_stream, do: @octet_stream

  @doc "Return the content type for a path."
  @spec type(String.t()) :: String.t()
  def type(path) do
    ext = path |> Path.extname() |> String.downcase()
    Map.get(@overrides, ext) || MIME.from_path(path)
  end

  @doc "Return whether a path is one of Volt's static asset file types."
  @spec asset?(String.t()) :: boolean()
  def asset?(path), do: MapSet.member?(@asset_exts, path |> Path.extname() |> String.downcase())

  @doc "Return whether a content type should be treated as JavaScript."
  @spec javascript?(String.t() | nil) :: boolean()
  def javascript?(content_type), do: content_type in [@javascript, "text/javascript"]

  @doc "Return whether a content type should be treated as CSS."
  @spec css?(String.t() | nil) :: boolean()
  def css?(content_type), do: content_type == @css
end
