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
    path
    |> File.read!()
    |> Jason.decode!()
    |> tags(opts)
  end

  def tags(manifest, opts) when is_map(manifest) do
    prefix = Keyword.get(opts, :prefix, Volt.Paths.prefix())

    manifest
    |> preload_files(Keyword.get(opts, :entry))
    |> Enum.map(fn filename ->
      [~s(<link rel="modulepreload" href="), escape_attr(Volt.URL.join(prefix, filename)), ~s(">)]
    end)
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp preload_files(manifest, nil) do
    manifest
    |> Enum.map(fn
      {_key, %{"file" => file}} -> file
      {_key, file} when is_binary(file) -> file
    end)
    |> js_files()
  end

  defp preload_files(manifest, entry) do
    case Map.get(manifest, entry) do
      %{} = chunk -> imported_files(manifest, chunk)
      _ -> []
    end
  end

  defp imported_files(manifest, chunk), do: imported_files(manifest, chunk, MapSet.new())

  defp imported_files(manifest, chunk, seen) do
    chunk
    |> Map.get("imports", [])
    |> Enum.reject(&MapSet.member?(seen, &1))
    |> Enum.flat_map(fn file ->
      [file | imported_files(manifest, manifest[file] || %{}, MapSet.put(seen, file))]
    end)
    |> js_files()
  end

  defp escape_attr(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp js_files(files) do
    files
    |> Enum.uniq()
    |> Enum.filter(&String.ends_with?(&1, ".js"))
    |> Enum.sort()
  end
end
