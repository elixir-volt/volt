defmodule Volt.HTMLEntry do
  @moduledoc """
  Extract entry points from HTML files.

  Parses `<script src="...">` and `<link rel="stylesheet" href="...">` tags
  to discover JS and CSS entry files, similar to Vite's HTML-driven builds.

  ## Example

      # index.html
      <script type="module" src="js/app.ts"></script>
      <link rel="stylesheet" href="css/app.css">

      # Extract entries
      {:ok, entries} = Volt.HTMLEntry.extract("index.html")
      entries.scripts  #=> ["js/app.ts"]
      entries.styles   #=> ["css/app.css"]
  """

  @script_re ~r/<script[^>]+src=["']([^"']+)["'][^>]*>/i
  @style_re ~r/<link[^>]+rel=["']stylesheet["'][^>]+href=["']([^"']+)["'][^>]*>/i
  @style_re_alt ~r/<link[^>]+href=["']([^"']+)["'][^>]+rel=["']stylesheet["'][^>]*>/i

  @doc """
  Extract script and stylesheet entries from an HTML file.

  Returns `{:ok, %{scripts: [path], styles: [path]}}`.
  Paths are relative to the HTML file's directory.
  """
  @spec extract(String.t()) :: {:ok, %{scripts: [String.t()], styles: [String.t()]}}
  def extract(html_path) do
    html_path = Path.expand(html_path)
    html = File.read!(html_path)

    scripts =
      @script_re
      |> Regex.scan(html)
      |> Enum.map(fn [_, src] -> resolve_path(src, html_path) end)

    styles =
      (@style_re |> Regex.scan(html))
      |> Kernel.++(Regex.scan(@style_re_alt, html))
      |> Enum.map(fn [_, href] -> resolve_path(href, html_path) end)
      |> Enum.uniq()

    {:ok, %{scripts: scripts, styles: styles}}
  end

  @doc """
  Check if a path is an HTML file.
  """
  @spec html?(String.t()) :: boolean()
  def html?(path), do: Path.extname(path) in ~w(.html .htm)

  defp resolve_path(src, html_path) do
    if String.starts_with?(src, "/") do
      src
    else
      html_path |> Path.dirname() |> Path.join(src) |> Path.expand()
    end
  end
end
