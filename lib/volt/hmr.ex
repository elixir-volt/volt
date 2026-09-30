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
  def broadcast(type, payload \\ nil, opts \\ []) do
    session = Keyword.get(opts, :session, :default)

    Registry.dispatch(Volt.HMR.Registry, Volt.HMR.Channel.key(session), fn entries ->
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

    broadcast(:update, payload, opts)
  end

  @doc "Broadcast a full page reload request for a changed path."
  @spec full_reload(String.t()) :: :ok
  def full_reload(path, opts \\ []), do: update(path, [:full], opts)

  @doc "Broadcast a style-only update for a changed stylesheet path."
  @spec style_update(String.t()) :: :ok
  def style_update(path, opts \\ []), do: update(path, [:style], opts)

  @doc """
  Report the errors for a source path and show them in connected browsers.

  `reason` may be `OXC.Diagnostic` maps, messages, exceptions, or any other term;
  see `Volt.Dev.Error.entries/2`. The errors stay current until `clear_error/2`,
  so browsers that connect later show them too.

  ## Options

    * `:session` — the development session. Default: `:default`
    * `:title` — the overlay heading for these errors, such as `"Render error"`.
      Default: `"Build error"`
  """
  @spec error(String.t(), term(), keyword()) :: :ok
  def error(path, reason, opts \\ []) do
    session = Keyword.get(opts, :session, :default)
    entries = Volt.Dev.Error.entries(reason, file: path, title: Keyword.get(opts, :title))
    Volt.HMR.Errors.put(session, path, entries)
    broadcast_errors(session)
  end

  @doc "Clear the errors reported for a source path, hiding the overlay when none remain."
  @spec clear_error(String.t(), keyword()) :: :ok
  def clear_error(path, opts \\ []) do
    session = Keyword.get(opts, :session, :default)
    if Volt.HMR.Errors.delete(session, path), do: broadcast_errors(session), else: :ok
  end

  defp broadcast_errors(session) do
    broadcast(:error, %{errors: Volt.HMR.Errors.list(session)}, session: session)
  end

  @doc "Invalidate Volt's dev compilation state for a source file without broadcasting."
  @spec invalidate_file(String.t()) :: :ok
  def invalidate_file(path, opts \\ []) do
    session = Keyword.get(opts, :session, :default)
    Volt.Cache.evict_file(path, session)
    Volt.HMR.ModuleGraph.invalidate_file(path, System.system_time(:millisecond), session)
    :ok
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
