defmodule Volt.ETS do
  @moduledoc "Small helpers for Volt's named ETS tables."

  @doc "Resolve an owned session table or the legacy table at the API boundary."
  def session_table(%Volt.Dev.Session.Tables{} = tables, kind, _legacy),
    do: Map.fetch!(tables, kind)

  def session_table(_session, _kind, legacy), do: legacy

  @doc "Create a public named set table optimized for concurrent reads."
  def create_named_set(table) do
    :ets.new(table, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc "Insert one row into an ETS table and return `:ok`."
  def put(table, row) do
    :ets.insert(table, row)
    :ok
  end

  @doc "Delete one key from an ETS table and return `:ok`."
  def delete(table, key) do
    :ets.delete(table, key)
    :ok
  end

  @doc "Delete rows keyed by {session, key} for one exact session."
  def clear_session(table, session) do
    :ets.select_delete(table, [{{{:"$1", :_}, :_}, [{:"=:=", :"$1", {:const, session}}], [true]}])
    :ok
  end

  @doc "Remove all rows from an ETS table and return `:ok`."
  def clear(table) do
    :ets.delete_all_objects(table)
    :ok
  end
end
