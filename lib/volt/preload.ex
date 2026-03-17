defmodule Volt.Preload do
  @moduledoc """
  Generate `<link rel="modulepreload">` tags for production chunks.

  When using code splitting, async chunks should be preloaded to avoid
  waterfall loading. This module generates the HTML tags from the build manifest.

  ## Example

      Volt.Preload.tags("priv/static/assets/js/manifest.json", prefix: "/assets/js")
      #=> ~s(<link rel="modulepreload" href="/assets/js/app-a1b2c3d4.js">\\n...)
  """

  @doc """
  Generate modulepreload link tags from a manifest file or map.

  ## Options

    * `:prefix` — URL prefix for assets (default: `"/assets"`)
    * `:entry` — only preload chunks related to this entry name
  """
  @spec tags(String.t() | map(), keyword()) :: String.t()
  def tags(manifest, opts \\ [])

  def tags(path, opts) when is_binary(path) do
    manifest = path |> File.read!() |> :json.decode()
    tags(manifest, opts)
  end

  def tags(manifest, opts) when is_map(manifest) do
    prefix = Keyword.get(opts, :prefix, "/assets")

    manifest
    |> Map.values()
    |> Enum.uniq()
    |> Enum.filter(&String.ends_with?(&1, ".js"))
    |> Enum.sort()
    |> Enum.map_join("\n", fn filename ->
      ~s(<link rel="modulepreload" href="#{prefix}/#{filename}">)
    end)
  end
end
