defmodule Volt.HMR.StyleGraph do
  @moduledoc """
  ETS-backed stylesheet dependency graph for HMR invalidation.

  The graph stores resolved stylesheet dependencies and reverse dependent links.
  Dependency discovery belongs to `Volt.CSS.Dependencies`; this module only owns
  the dev-server state needed to invalidate and hot-update stylesheets when an
  imported stylesheet or referenced asset changes.
  """

  @table :volt_hmr_style_graph

  @doc "Create the stylesheet graph ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table, do: Volt.ETS.create_named_set(@table)

  @doc "Update resolved dependencies for a stylesheet source file."
  @spec update(String.t(), [String.t()]) :: :ok
  def update(path, dependencies) do
    old_dependencies = dependencies_of(path)
    dependencies = dependencies |> Enum.uniq() |> MapSet.new()

    Enum.each(old_dependencies, fn dependency ->
      dependents = dependency |> dependents_of() |> MapSet.new() |> MapSet.delete(path)
      put_dependents(dependency, dependents)
    end)

    Volt.ETS.put(@table, {{:dependencies, path}, dependencies})

    Enum.each(dependencies, fn dependency ->
      dependents = dependency |> dependents_of() |> MapSet.new() |> MapSet.put(path)
      put_dependents(dependency, dependents)
    end)

    :ok
  end

  @doc "Return direct resolved dependencies for a stylesheet source file."
  @spec dependencies_of(String.t()) :: [String.t()]
  def dependencies_of(path), do: lookup_set({:dependencies, path})

  @doc "Return all transitive stylesheets that depend on a source file."
  @spec dependents(String.t()) :: [String.t()]
  def dependents(path), do: dependents(path, MapSet.new([path]))

  @doc "Remove a stylesheet from the graph."
  @spec remove(String.t()) :: :ok
  def remove(path) do
    update(path, [])
    Volt.ETS.delete(@table, {:dependencies, path})
    Volt.ETS.delete(@table, {:dependents, path})
    :ok
  end

  @doc "Clear the entire graph."
  @spec clear :: :ok
  def clear, do: Volt.ETS.clear(@table)

  defp dependents(path, seen) do
    path
    |> dependents_of()
    |> Enum.reject(&MapSet.member?(seen, &1))
    |> Enum.flat_map(fn stylesheet ->
      [stylesheet | dependents(stylesheet, MapSet.put(seen, stylesheet))]
    end)
    |> Enum.uniq()
  end

  defp dependents_of(path), do: lookup_set({:dependents, path})

  defp put_dependents(path, dependents) do
    if MapSet.size(dependents) == 0 do
      Volt.ETS.delete(@table, {:dependents, path})
    else
      Volt.ETS.put(@table, {{:dependents, path}, dependents})
    end
  end

  defp lookup_set(key) do
    case :ets.lookup(@table, key) do
      [{_, set}] -> MapSet.to_list(set)
      [] -> []
    end
  end
end
