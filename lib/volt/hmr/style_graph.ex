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
  def update(path, dependencies, session \\ :default) do
    old_dependencies = dependencies_of(path, session)
    dependencies = dependencies |> Enum.uniq() |> MapSet.new()

    Enum.each(old_dependencies, fn dependency ->
      dependents = dependency |> dependents_of(session) |> MapSet.new() |> MapSet.delete(path)
      put_dependents(dependency, dependents, session)
    end)

    Volt.ETS.put(@table, {{session, {:dependencies, path}}, dependencies})

    Enum.each(dependencies, fn dependency ->
      dependents = dependency |> dependents_of(session) |> MapSet.new() |> MapSet.put(path)
      put_dependents(dependency, dependents, session)
    end)

    :ok
  end

  @doc "Return direct resolved dependencies for a stylesheet source file."
  @spec dependencies_of(String.t()) :: [String.t()]
  def dependencies_of(path, session \\ :default), do: lookup_set({session, {:dependencies, path}})

  @doc "Return all transitive stylesheets that depend on a source file."
  @spec dependents(String.t()) :: [String.t()]
  def dependents(path, session \\ :default),
    do: walk_dependents(path, MapSet.new([path]), session)

  @doc "Remove a stylesheet from the graph."
  @spec remove(String.t()) :: :ok
  def remove(path, session \\ :default) do
    update(path, [], session)
    Volt.ETS.delete(@table, {session, {:dependencies, path}})
    Volt.ETS.delete(@table, {session, {:dependents, path}})
    :ok
  end

  @doc "Clear the entire graph."
  @spec clear :: :ok
  def clear, do: Volt.ETS.clear(@table)

  @doc "Clear stylesheet edges belonging to one session."
  def clear_session(session), do: Volt.ETS.clear_session(@table, session)

  defp walk_dependents(path, seen, session) do
    path
    |> dependents_of(session)
    |> Enum.reject(&MapSet.member?(seen, &1))
    |> Enum.flat_map(fn stylesheet ->
      [stylesheet | walk_dependents(stylesheet, MapSet.put(seen, stylesheet), session)]
    end)
    |> Enum.uniq()
  end

  defp dependents_of(path, session), do: lookup_set({session, {:dependents, path}})

  defp put_dependents(path, dependents, session) do
    if MapSet.size(dependents) == 0 do
      Volt.ETS.delete(@table, {session, {:dependents, path}})
    else
      Volt.ETS.put(@table, {{session, {:dependents, path}}, dependents})
    end
  end

  defp lookup_set(key) do
    case :ets.lookup(@table, key) do
      [{_, set}] -> MapSet.to_list(set)
      [] -> []
    end
  end
end
