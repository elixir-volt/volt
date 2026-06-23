defmodule Volt.CSS.Dependencies do
  @moduledoc """
  Extracts and resolves local stylesheet dependencies.

  Uses Vize's parser-backed CSS dependency selector to discover both `@import`
  and `url()` references. Remote, root-relative, fragment-only, data, and empty
  references are ignored because they are not files watched by Volt's source
  graph.
  """

  @doc "Resolve local stylesheet dependencies in CSS source to absolute file paths."
  @spec resolve(String.t(), String.t()) :: [String.t()]
  def resolve(source, path) do
    case Vize.CSS.select(source, :dependencies, filename: path) do
      {:ok, dependencies} -> resolve_selected(dependencies, path)
      {:error, _} -> []
    end
  end

  @doc "Resolve selected CSS dependency events to absolute file paths."
  @spec resolve_selected([map()], String.t()) :: [String.t()]
  def resolve_selected(dependencies, path) do
    dependencies
    |> Enum.flat_map(&resolve_dependency(&1, path))
    |> Enum.uniq()
  end

  defp resolve_dependency(%{kind: :import, url: url}, path), do: resolve_import(url, path)
  defp resolve_dependency(%{kind: :url, url: url}, path), do: resolve_url(url, path)
  defp resolve_dependency(_dependency, _path), do: []

  defp resolve_import(url, path) do
    with {:ok, local_path} <- local_path(url, path),
         resolved_path when is_binary(resolved_path) <- resolve_stylesheet_path(local_path) do
      [resolved_path]
    else
      _ -> []
    end
  end

  defp resolve_url(url, path) do
    with {:ok, local_path} <- local_path(url, path),
         true <- File.regular?(local_path) do
      [local_path]
    else
      _ -> []
    end
  end

  defp local_path(url, path) do
    uri = URI.parse(url)

    cond do
      not is_binary(uri.path) or uri.path == "" ->
        :error

      uri.scheme || uri.host || String.starts_with?(url, ["/", "#", "//"]) ->
        :error

      true ->
        {:ok, Path.expand(uri.path, Path.dirname(path))}
    end
  end

  defp resolve_stylesheet_path(path) do
    [path, path <> ".css", Path.join(path, "index.css")]
    |> Enum.find(&File.regular?/1)
  end
end
