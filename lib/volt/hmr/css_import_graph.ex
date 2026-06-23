defmodule Volt.HMR.CSSImportGraph do
  @moduledoc """
  Tracks stylesheet `@import` file dependencies for CSS HMR invalidation.

  The graph is populated from `Vize.CSS.select/3` using the public `:imports`
  selector. It stores resolved local stylesheet paths so a change to an imported
  stylesheet can invalidate and hot-update served importer stylesheets.
  """

  @table :volt_hmr_css_import_graph

  @doc "Create the CSS import graph ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table, do: Volt.ETS.create_named_set(@table)

  @doc "Update CSS imports for a stylesheet source file."
  @spec update_from_source(String.t(), String.t()) :: :ok
  def update_from_source(path, source) do
    imports =
      case Vize.CSS.select(source, :imports, filename: path) do
        {:ok, imports} -> resolve_imports(imports, path)
        {:error, _} -> []
      end

    update(path, imports)
  end

  @doc "Update resolved imports for a stylesheet source file."
  @spec update(String.t(), [String.t()]) :: :ok
  def update(path, imports) do
    old_imports = imports_of(path)
    imports = imports |> Enum.uniq() |> MapSet.new()

    Enum.each(old_imports, fn import ->
      importers = import |> importers_of() |> MapSet.new() |> MapSet.delete(path)
      put_importers(import, importers)
    end)

    Volt.ETS.put(@table, {{:imports, path}, imports})

    Enum.each(imports, fn import ->
      importers = import |> importers_of() |> MapSet.new() |> MapSet.put(path)
      put_importers(import, importers)
    end)

    :ok
  end

  @doc "Return direct resolved imports for a stylesheet source file."
  @spec imports_of(String.t()) :: [String.t()]
  def imports_of(path), do: lookup_set({:imports, path})

  @doc "Return all transitive stylesheet importers for a stylesheet source file."
  @spec dependents(String.t()) :: [String.t()]
  def dependents(path), do: dependents(path, MapSet.new())

  @doc "Remove a stylesheet from the graph."
  @spec remove(String.t()) :: :ok
  def remove(path) do
    update(path, [])
    Volt.ETS.delete(@table, {:imports, path})
    Volt.ETS.delete(@table, {:importers, path})
    :ok
  end

  @doc "Clear the entire graph."
  @spec clear :: :ok
  def clear, do: Volt.ETS.clear(@table)

  defp dependents(path, seen) do
    path
    |> importers_of()
    |> Enum.reject(&MapSet.member?(seen, &1))
    |> Enum.flat_map(fn importer ->
      [importer | dependents(importer, MapSet.put(seen, importer))]
    end)
    |> Enum.uniq()
  end

  defp resolve_imports(imports, path) do
    imports
    |> Enum.map(&Map.fetch!(&1, :url))
    |> Enum.flat_map(&resolve_import(&1, path))
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

  defp importers_of(path), do: lookup_set({:importers, path})

  defp put_importers(path, importers) do
    if MapSet.size(importers) == 0 do
      Volt.ETS.delete(@table, {:importers, path})
    else
      Volt.ETS.put(@table, {{:importers, path}, importers})
    end
  end

  defp lookup_set(key) do
    case :ets.lookup(@table, key) do
      [{_, set}] -> MapSet.to_list(set)
      [] -> []
    end
  end
end
