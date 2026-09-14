defmodule Volt.Dev.Assets do
  @moduledoc "Session-owned URL grants for assets resolved from project stylesheets."

  @table :volt_dev_assets
  @prefix "/@volt/assets/"

  def create_table do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc "Grant a browser URL to an already resolved asset; never accepts browser-supplied paths."
  def register(path, session) do
    path = Path.expand(path)
    id = :crypto.hash(:sha256, path) |> Base.encode16(case: :lower)
    {table, key} = location(session, id)
    :ets.insert(table, {key, path})
    @prefix <> id
  end

  def fetch(id, session) do
    {table, key} = location(session, id)

    case :ets.lookup(table, key) do
      [{^key, path}] -> {:ok, path}
      [] -> :error
    end
  end

  def clear_session(session), do: Volt.ETS.clear_session(@table, session)

  defp location(%Volt.Dev.Session.Tables{assets: table}, id), do: {table, id}
  defp location(session, id), do: {@table, {session, id}}
end
