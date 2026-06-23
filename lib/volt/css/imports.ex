defmodule Volt.CSS.Imports do
  @moduledoc """
  Extracts and resolves local stylesheet `@import` dependencies.

  Uses Vize's parser-backed CSS selector API to discover `@import` references,
  then resolves local relative specifiers against the importing stylesheet.
  Remote, root-relative, fragment-only, and empty imports are ignored because
  they are not files watched by Volt's source graph.
  """

  @doc "Resolve local stylesheet imports in CSS source to absolute file paths."
  @spec resolve(String.t(), String.t()) :: [String.t()]
  def resolve(source, path) do
    case Vize.CSS.select(source, :imports, filename: path) do
      {:ok, imports} -> resolve_selected(imports, path)
      {:error, _} -> []
    end
  end

  @doc "Resolve selected CSS import events to absolute file paths."
  @spec resolve_selected([map()], String.t()) :: [String.t()]
  def resolve_selected(imports, path) do
    imports
    |> Enum.map(&Map.fetch!(&1, :url))
    |> Enum.flat_map(&resolve_import(&1, path))
    |> Enum.uniq()
  end

  defp resolve_import(url, path) do
    uri = URI.parse(url)

    cond do
      not is_binary(uri.path) or uri.path == "" ->
        []

      uri.scheme || uri.host || String.starts_with?(url, ["/", "#", "//"]) ->
        []

      true ->
        [Path.expand(uri.path, Path.dirname(path))]
    end
  end
end
