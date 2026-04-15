defmodule Volt.DepGraph do
  @moduledoc """
  ETS-backed module dependency graph.

  Tracks which files import which specifiers, enabling reverse lookups
  for HMR propagation — "what depends on this file?"
  """

  @table :volt_dep_graph

  @doc "Create the dependency graph ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc "Update the imports for a file path."
  @spec update(String.t(), [String.t()]) :: :ok
  def update(path, imports) do
    :ets.insert(@table, {path, imports})
    :ok
  end

  @doc "Get the imports for a file path."
  @spec imports_of(String.t()) :: [String.t()]
  def imports_of(path) do
    case :ets.lookup(@table, path) do
      [{_, imports}] -> imports
      [] -> []
    end
  end

  @doc """
  Find all files that import the given specifier.

  Used by HMR to propagate changes upward through the dependency tree.
  """
  @spec dependents(String.t()) :: [String.t()]
  def dependents(specifier) do
    :ets.foldl(
      fn {path, imports}, acc ->
        if specifier in imports, do: [path | acc], else: acc
      end,
      [],
      @table
    )
  end

  @doc """
  Find all files that import a specifier matching the given predicate.

  The predicate receives each import specifier and should return `true`
  if it matches the file being searched for.
  """
  @spec dependents_matching((String.t() -> boolean())) :: [String.t()]
  def dependents_matching(predicate) do
    :ets.foldl(
      fn {path, imports}, acc ->
        if Enum.any?(imports, predicate), do: [path | acc], else: acc
      end,
      [],
      @table
    )
  end

  @doc "Remove a file from the graph."
  @spec remove(String.t()) :: :ok
  def remove(path) do
    :ets.delete(@table, path)
    :ok
  end

  @doc "Clear the entire graph."
  @spec clear :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end
end
