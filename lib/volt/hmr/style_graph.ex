defmodule Volt.HMR.StyleGraph do
  @moduledoc """
  ETS-backed stylesheet dependency graph for HMR invalidation.

  The graph stores resolved stylesheet dependencies and reverse importer links.
  Dependency discovery belongs to `Volt.CSS.Imports`; this module only owns the
  dev-server state needed to invalidate and hot-update importer stylesheets when
  an imported stylesheet changes.
  """

  @table :volt_hmr_style_graph

  @doc "Create the stylesheet graph ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table, do: Volt.ETS.create_named_set(@table)

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
  def dependents(path), do: dependents(path, MapSet.new([path]))

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
