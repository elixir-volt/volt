defmodule Volt.Cache do
  @moduledoc """
  ETS-backed module cache keyed by path.

  Caches compiled output so repeated requests for unchanged files
  skip the compilation step entirely.
  """

  @table :volt_cache

  @type entry :: Volt.DevServer.CacheEntry.t()

  @type cache_entry :: %{mtime: integer(), entry: entry()}

  defp location(%Volt.Dev.Session.Tables{cache: table}, path), do: {table, path}
  defp location(session, path), do: {@table, {session, path}}

  @doc "Create the cache ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc "Look up a cached entry. Returns `nil` on miss."
  @spec get(String.t(), integer()) :: entry() | nil
  def get(path, mtime, session \\ :default) do
    {table, key} = location(session, path)

    case :ets.lookup(table, key) do
      [{^key, %{mtime: ^mtime, entry: entry}}] -> entry
      _ -> nil
    end
  end

  @doc "Look up any cached entry for a file path regardless of mtime."
  @spec get_file(String.t()) :: entry() | nil
  def get_file(path, session \\ :default) do
    {table, key} = location(session, path)

    case :ets.lookup(table, key) do
      [{^key, %{entry: entry}}] -> entry
      [] -> nil
    end
  end

  @doc "Store a compiled entry."
  @spec put(String.t(), integer(), entry()) :: :ok
  def put(path, mtime, entry, session \\ :default) do
    {table, key} = location(session, path)
    :ets.insert(table, {key, %{mtime: mtime, entry: entry}})
    :ok
  end

  @doc "Evict the entry for a cache key."
  @spec evict(String.t()) :: :ok
  def evict(key, session \\ :default) do
    {table, key} = location(session, key)
    :ets.delete(table, key)
    :ok
  end

  @doc "Evict all cache entries derived from a file path, including variant keys like `path <> \"?import\"`."
  @spec evict_file(String.t()) :: :ok
  def evict_file(path, session \\ :default) do
    evict(path, session)
    evict(Volt.URL.append_query(path, "import"), session)
    :ok
  end

  @doc "Clear entries belonging to one development session."
  def clear_session(session), do: Volt.ETS.clear_session(@table, session)

  @doc "Clear all cached entries."
  @spec clear :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end
end
