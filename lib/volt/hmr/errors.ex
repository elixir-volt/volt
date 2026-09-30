defmodule Volt.HMR.Errors do
  @moduledoc false
  # Current development errors per session and source path, so browsers that
  # connect after a failure still show the overlay.

  @table :volt_hmr_errors

  def create_table, do: Volt.ETS.create_named_set(@table)

  def put(session, path, entries), do: Volt.ETS.put(@table, {{session, path}, entries})

  @doc "Remove the errors for a path and return whether there were any."
  def delete(session, path), do: :ets.take(@table, {session, path}) != []

  def list(session) do
    @table
    |> :ets.match_object({{session, :_}, :_})
    |> Enum.sort()
    |> Enum.flat_map(fn {_key, entries} -> entries end)
  end

  def clear_session(session), do: Volt.ETS.clear_session(@table, session)
end
