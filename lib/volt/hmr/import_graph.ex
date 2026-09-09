defmodule Volt.HMR.ImportGraph do
  @moduledoc """
  ETS-backed raw import graph for HMR boundary fallback.

  The dev server records resolved module relationships in `Volt.HMR.ModuleGraph`.
  This graph keeps parser-extracted import specifiers as a fallback for files
  that have not been served through the dev module graph yet.
  """

  @table :volt_hmr_import_graph

  defp table(session), do: Volt.ETS.session_table(session, :imports, @table)

  @doc "Create the import graph ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table, do: Volt.ETS.create_named_set(@table)

  @doc "Update the imports for a file path."
  @spec update(String.t(), [String.t()]) :: :ok
  def update(path, imports, session \\ :default) do
    Volt.ETS.put(table(session), {{session, path}, Enum.uniq(imports)})
  end

  @doc "Update imports from compiled code."
  @spec update_from_compiled(String.t(), String.t()) :: :ok
  def update_from_compiled(path, compiled_code, session \\ :default) do
    imports =
      case OXC.select(compiled_code, Path.basename(path), :import_specifiers) do
        {:ok, imports} -> imports
        _ -> []
      end

    update(path, imports, session)
  end

  @doc "Get the imports for a file path."
  @spec imports_of(String.t()) :: [String.t()]
  def imports_of(path, session \\ :default) do
    case :ets.lookup(table(session), {session, path}) do
      [{_, imports}] -> imports
      [] -> []
    end
  end

  @doc """
  Find all files that import the given specifier.

  Used by fallback HMR boundary lookup to propagate changes upward through raw imports.
  """
  @spec dependents(String.t()) :: [String.t()]
  def dependents(specifier, session \\ :default) do
    dependents_matching(&(&1 == specifier), session)
  end

  @doc """
  Find all files that import a specifier matching the given predicate.

  The predicate receives each import specifier and should return `true`
  if it matches the file being searched for.
  """
  @spec dependents_matching((String.t() -> boolean())) :: [String.t()]
  def dependents_matching(predicate, session \\ :default) do
    :ets.foldl(
      fn
        {{^session, path}, imports}, acc ->
          if Enum.any?(imports, predicate), do: [path | acc], else: acc

        _, acc ->
          acc
      end,
      [],
      table(session)
    )
  end

  @doc "Remove a file from the graph."
  @spec remove(String.t()) :: :ok
  def remove(path, session \\ :default), do: Volt.ETS.delete(table(session), {session, path})

  @doc "Clear the entire graph."
  @spec clear :: :ok
  def clear, do: Volt.ETS.clear(@table)

  @doc "Clear raw import edges for one session."
  def clear_session(session), do: Volt.ETS.clear_session(table(session), session)
end
