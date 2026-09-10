defmodule Volt.Dev.Session.Supervisor do
  @moduledoc "Supervision boundary for a development session's state and dependent services."

  use Supervisor

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    Supervisor.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc "Read the current generation from a running session subtree."
  def tables(supervisor), do: Volt.Dev.Session.Call.run(fn -> read_tables(supervisor) end)

  defp read_tables(supervisor) do
    case Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
           id == Volt.Dev.Session.State
         end) do
      {_, pid, _, _} when is_pid(pid) -> Volt.Dev.Session.State.tables(pid)
      _ -> {:error, :session_restarting}
    end
  end

  @doc "Read the session's last successful stylesheet."
  def stylesheet(supervisor), do: Volt.Dev.Session.Call.run(fn -> read_stylesheet(supervisor) end)

  defp read_stylesheet(supervisor) do
    case Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
           id == Volt.Tailwind.Worker
         end) do
      {_, pid, _, _} when is_pid(pid) -> Volt.Tailwind.Worker.stylesheet(pid)
      _ -> {:error, :session_restarting}
    end
  end

  @impl true
  def init(opts) do
    # State must start first. Its replacement invalidates every dependent child's handles.
    children =
      case Keyword.fetch(opts, :watcher) do
        {:ok, watcher_opts} ->
          identity = Keyword.fetch!(opts, :identity)
          owner_name = {:via, Registry, {Volt.Dev.WatcherRegistry, {:state_owner, identity}}}

          runtime_name = {:via, Registry, {Volt.Dev.WatcherRegistry, {:compiler, identity}}}

          worker_name = {:via, Registry, {Volt.Dev.WatcherRegistry, {:stylesheet, identity}}}

          [
            {Volt.Dev.Session.State, name: owner_name},
            {Volt.Tailwind.Runtime, name: runtime_name},
            {Volt.Tailwind.Worker,
             name: worker_name, key: {:session, identity}, runtime: runtime_name},
            {Volt.Dev.Session.Watcher,
             watcher_opts
             |> Keyword.put(
               :configuration_signature,
               watcher_opts |> Keyword.delete(:name) |> Map.new()
             )
             |> Keyword.put(:tailwind_outdir, Keyword.get(watcher_opts, :tailwind_sink))
             |> Keyword.put(:state_owner, owner_name)
             |> Keyword.put(:tailwind_worker, worker_name)
             |> Keyword.put(:tailwind_runtime, runtime_name)}
          ]

        :error ->
          [{Volt.Dev.Session.State, []} | Keyword.get(opts, :children, [])]
      end

    Supervisor.init(children, strategy: :rest_for_one, auto_shutdown: :any_significant)
  end
end
