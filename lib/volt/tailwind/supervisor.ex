defmodule Volt.Tailwind.Supervisor do
  @moduledoc false

  @registry Volt.Tailwind.Registry
  @supervisor Volt.Tailwind.WorkerSupervisor

  @spec worker(term(), keyword()) :: GenServer.server()
  def worker(key, opts) do
    name = {:via, Registry, {@registry, key}}

    case Registry.lookup(@registry, key) do
      [{pid, _value}] ->
        pid

      [] ->
        spec = {Volt.Tailwind.Worker, Keyword.merge(opts, key: key, name: name)}

        case DynamicSupervisor.start_child(@supervisor, spec) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
          {:error, reason} -> raise "could not start Tailwind worker: #{inspect(reason)}"
        end
    end
  end
end
