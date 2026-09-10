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

  @doc "Start a supervised generation with a state owner and watcher."
  def start_supervised_session(session, opts) when session != :default do
    watcher_opts = opts |> Keyword.put(:session, session) |> Keyword.put(:name, nil)
    Volt.Dev.Session.Supervisor.start_link(identity: session, watcher: watcher_opts)
  end

  @doc "Start or reuse a managed watcher, rejecting conflicting configuration."
  def start(opts) do
    session = session_identity(opts)
    root = opts |> Keyword.fetch!(:root) |> Path.expand()
    key = {:session, session}
    opts = normalize_options(Keyword.put(opts, :session, session), root)

    :global.trans(
      {{__MODULE__, key}, self()},
      fn ->
        Volt.Dev.Session.Call.run(fn -> start_watcher(key, opts) end)
      end,
      [node()]
    )
  end

  defp start_watcher({:session, session} = key, opts) do
    name = {:via, Registry, {@registry, key}}

    result =
      case GenServer.whereis(name) do
        nil ->
          spec =
            Supervisor.child_spec(
              {Volt.Dev.Session.Supervisor,
               [name: name, identity: session, watcher: Keyword.put(opts, :name, nil)]},
              restart: :transient
            )

          DynamicSupervisor.start_child(@supervisor, spec)

        pid ->
          {:ok, pid}
      end

    case result do
      {:ok, supervisor} -> verify_session(supervisor, opts)
      {:error, {:already_started, supervisor}} -> verify_session(supervisor, opts)
      error -> error
    end
  end

  @doc "Normalize omitted session identity from profile and asset root."
  def session_identity(opts) do
    case Keyword.get(opts, :session, :default) do
      :default ->
        {:managed, Keyword.get(opts, :id, :default), Path.expand(Keyword.fetch!(opts, :root))}

      session ->
        session
    end
  end

  defp verify_session(supervisor, opts) do
    case Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
           id == Volt.Dev.Session.Watcher
         end) do
      {_, pid, _, _} when is_pid(pid) -> verify_configuration(pid, opts)
      _ -> {:error, :session_restarting}
    end
  end

  @doc "Read CSS from the worker owned by a managed session."
  def stylesheet(session) do
    case Registry.lookup(@registry, {:session, session}) do
      [{supervisor, _}] -> Volt.Dev.Session.Supervisor.stylesheet(supervisor)
      [] -> {:error, :session_not_started}
    end
  end

  @doc "Resolve the current owned generation for an explicitly identified session."
  def tables(session) when session != :default do
    case Registry.lookup(@registry, {:session, session}) do
      [{supervisor, _}] -> Volt.Dev.Session.Supervisor.tables(supervisor)
      [] -> {:error, :session_not_started}
    end
  end

  @doc "Stop an explicitly identified session and clear its compilation state."
  def stop(:default), do: {:error, :explicit_session_required}

  def stop(session) do
    :global.trans({{__MODULE__, {:session, session}}, self()}, fn -> stop_session(session) end, [
      node()
    ])
  end

  defp stop_session(session) do
    case Registry.lookup(@registry, {:session, session}) do
      [] ->
        :ok

      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(@supervisor, pid) do
          {:error, :not_found} -> :ok
          result -> result
        end
    end

    Volt.Dev.State.clear(session)
  end

  defp normalize_options(opts, root) do
    opts
    |> Keyword.delete(:id)
    |> Keyword.put(:root, root)
    |> Keyword.put_new(:session, :default)
    |> Keyword.update(:watch_dirs, [], &Enum.map(&1, fn path -> Path.expand(path) end))
    |> Keyword.update(:reload_dirs, [], &Enum.map(&1, fn path -> Path.expand(path) end))
  end

  defp verify_configuration(pid, opts) do
    signature = opts |> Keyword.drop([:name, :managed_key]) |> Map.new()

    if GenServer.call(pid, {:configuration_matches, signature}),
      do: {:ok, pid},
      else: {:error, :session_configuration_conflict}
  end

  defp dev_supervision_started? do
    is_pid(Process.whereis(@registry)) and is_pid(Process.whereis(@supervisor))
  end
end
