defmodule Volt.HTMLEntry do
  @moduledoc """
  Extract entry points from HTML files.

  Parses `<script src="...">` and `<link rel="stylesheet" href="...">` tags
  using Floki to discover JS and CSS entry files.

  ## Example

      # index.html
      <script type="module" src="js/app.ts"></script>
      <link rel="stylesheet" href="css/app.css">

      {:ok, entries} = Volt.HTMLEntry.extract("index.html")
      entries.scripts  #=> ["js/app.ts"]
      entries.styles   #=> ["css/app.css"]
  """

  @doc """
  Extract script and stylesheet entries from an HTML file.

  Paths are resolved relative to the HTML file's directory.
  """
  @spec extract(String.t()) :: {:ok, %{scripts: [String.t()], styles: [String.t()]}}
  def extract(html_path) do
    html_path = Path.expand(html_path)
    html = File.read!(html_path)
    {:ok, doc} = Floki.parse_document(html)

    scripts =
      doc
      |> Floki.find("script[src]")
      |> Enum.map(&Floki.attribute(&1, "src"))
      |> List.flatten()
      |> Enum.map(&resolve_path(&1, html_path))

    styles =
      doc
      |> Floki.find("link[rel=stylesheet][href]")
      |> Enum.map(&Floki.attribute(&1, "href"))
      |> List.flatten()
      |> Enum.map(&resolve_path(&1, html_path))

    {:ok, %{scripts: scripts, styles: styles}}
  end

  @doc "Check if a path is an HTML file."
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
