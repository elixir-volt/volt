defmodule Volt.Dev do
  @moduledoc false

  require Logger

  @registry Volt.Dev.WatcherRegistry
  @supervisor Volt.Dev.WatcherSupervisor

  @spec ensure_watcher(keyword() | false | nil) :: :ok
  def ensure_watcher(opts) when opts in [false, nil], do: :ok

  def ensure_watcher(opts) when is_list(opts) do
    result =
      if dev_supervision_started?() do
        start(opts)
      else
        {:error, :not_started}
      end

    case result do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("[Volt] Could not start file watcher: #{inspect(reason)}")
    end
  end

  @doc "Start or reuse a managed watcher, rejecting conflicting configuration."
  def start(opts) do
    {id, opts} = Keyword.pop(opts, :id, :default)

    session = Keyword.get(opts, :session, :default)
    root = opts |> Keyword.fetch!(:root) |> Path.expand()
    key = if session == :default, do: {:watcher, id, root}, else: {:session, session}
    opts = Keyword.put(opts, :root, root)
    name = {:via, Registry, {@registry, key}}

    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        verify_configuration(pid, opts)

      [] ->
        opts = Keyword.put(opts, :name, name)

        case DynamicSupervisor.start_child(@supervisor, {Volt.Watcher, opts}) do
          {:error, {:already_started, pid}} -> verify_configuration(pid, opts)
          result -> result
        end
    end
  end

  @doc "Stop an explicitly identified session and clear its compilation state."
  def stop(:default), do: {:error, :explicit_session_required}

  def stop(session) do
    case Registry.lookup(@registry, {:session, session}) do
      [] -> :ok
      [{pid, _}] -> DynamicSupervisor.terminate_child(@supervisor, pid)
    end
    |> case do
      :ok ->
        Volt.Cache.clear_session(session)
        Volt.HMR.ImportGraph.clear_session(session)
        Volt.HMR.GlobGraph.clear_session(session)
        Volt.HMR.StyleGraph.clear_session(session)
        Volt.HMR.ModuleGraph.clear_session(session)
        :ok

      error ->
        error
    end
  end

  defp verify_configuration(pid, opts) do
    signature = opts |> Keyword.delete(:name) |> Map.new()

    if GenServer.call(pid, {:configuration_matches, signature}),
      do: {:ok, pid},
      else: {:error, :session_configuration_conflict}
  end

  defp dev_supervision_started? do
    is_pid(Process.whereis(@registry)) and is_pid(Process.whereis(@supervisor))
  end
end
