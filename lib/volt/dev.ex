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
        start_watcher(opts)
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

  defp start_watcher(opts) do
    {id, opts} = Keyword.pop(opts, :id, :default)
    key = {:watcher, id, opts |> Keyword.fetch!(:root) |> Path.expand()}
    name = {:via, Registry, {@registry, key}}

    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        opts = Keyword.put(opts, :name, name)

        case DynamicSupervisor.start_child(@supervisor, {Volt.Watcher, opts}) do
          {:error, {:already_started, pid}} -> {:ok, pid}
          result -> result
        end
    end
  end

  defp dev_supervision_started? do
    is_pid(Process.whereis(@registry)) and is_pid(Process.whereis(@supervisor))
  end
end
