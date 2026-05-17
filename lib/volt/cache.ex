defmodule Volt.Cache do
  @moduledoc """
  ETS-backed module cache keyed by `{cache_key, mtime}`.

  Caches compiled output so repeated requests for unchanged files
  skip the compilation step entirely.
  """

  @table :volt_cache

  @type key :: String.t() | {:watcher, String.t()}

  @type entry :: %{
          code: String.t(),
          sourcemap: String.t() | nil,
          css: String.t() | nil,
          hashes:
            %{template: String.t() | nil, style: String.t() | nil, script: String.t() | nil}
            | nil,
          content_type: String.t()
        }

  @doc "Create the cache ETS table. Called once from Application.start/2."
  @spec create_table :: :ok
  def create_table do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc "Look up a cached entry. Returns `nil` on miss."
  @spec get(key(), integer()) :: entry() | nil
  def get(key, mtime) do
    case :ets.lookup(@table, {key, mtime}) do
      [{_, entry}] -> entry
      [] -> nil
    end
  end

  @doc "Store a compiled entry."
  @spec put(key(), integer(), entry()) :: :ok
  def put(key, mtime, entry) do
    :ets.insert(@table, {{key, mtime}, entry})
    :ok
  end

  @doc "Evict all entries for a cache key (any mtime)."
  @spec evict(key()) :: :ok
  def evict(key) do
    :ets.match_delete(@table, {{key, :_}, :_})
    :ok
  end

  @doc "Clear all cached entries."
  @spec clear :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end
end
