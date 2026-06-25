defmodule Volt.HMR do
  @moduledoc """
  Public helpers for broadcasting Volt HMR messages.

  These functions are intended for packages that compose Volt's dev server but
  own additional source graphs, such as static-site generators. They expose the
  same websocket protocol used internally by `Volt.Watcher` without requiring
  callers to reach into Volt's registry implementation.
  """

  @doc "Broadcast an HMR message to all connected clients."
  @spec broadcast(:update | :error | :ping | :pong, term()) :: :ok
  def broadcast(type, payload \\ nil) do
    Registry.dispatch(Volt.HMR.Registry, :clients, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:volt_hmr, type, payload})
      end
    end)

    :ok
  end

  @doc "Broadcast an update for a changed path."
  @spec update(String.t(), [atom() | String.t()], keyword()) :: :ok
  def update(path, changes, opts \\ []) do
    payload = %{
      path: path,
      changes: Enum.map(changes, &to_string/1)
    }

    payload = maybe_put(payload, :boundary, Keyword.get(opts, :boundary))
    payload = maybe_put(payload, :timestamp, Keyword.get(opts, :timestamp))

    broadcast(:update, payload)
  end

  @doc "Broadcast a full page reload request for a changed path."
  @spec full_reload(String.t()) :: :ok
  def full_reload(path), do: update(path, [:full])

  @doc "Broadcast a style-only update for a changed stylesheet path."
  @spec style_update(String.t()) :: :ok
  def style_update(path), do: update(path, [:style])

  @doc "Broadcast an error payload for a source path."
  @spec error(String.t(), term()) :: :ok
  def error(path, reason), do: broadcast(:error, %{path: path, reason: reason})

  @doc "Invalidate Volt's dev compilation state for a source file without broadcasting."
  @spec invalidate_file(String.t()) :: :ok
  def invalidate_file(path) do
    Volt.Cache.evict_file(path)
    Volt.HMR.ModuleGraph.invalidate_file(path)
    :ok
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
