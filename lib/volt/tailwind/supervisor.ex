defmodule Volt.Tailwind.Supervisor do
  @moduledoc false

  @registry Volt.Tailwind.Registry
  @supervisor Volt.Tailwind.WorkerSupervisor

  @doc "Release a compiler context without affecting other registered roots."
  def release(key) do
    # A watcher can terminate after these have stopped during application
    # shutdown, when there is nothing left to release.
    if Process.whereis(@registry) && Process.whereis(@supervisor) do
      case Registry.lookup(@registry, key) do
        [] -> :ok
        [{pid, _}] -> DynamicSupervisor.terminate_child(@supervisor, pid)
      end
    else
      :ok
    end
  end

  @doc "Resolve a lazy runtime shared only by contexts in one explicit session."
  def runtime({:session, session, _key}) do
    key = {:runtime, session}
    name = {:via, Registry, {@registry, key}}

    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        pid

      [] ->
        case DynamicSupervisor.start_child(@supervisor, {Volt.Tailwind.Runtime, [name: name]}) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end

  def runtime(_key), do: Volt.Tailwind.Runtime

  @doc "Release the compiler runtime owned by an explicit session."
  def release_runtime(session), do: release({:runtime, session})

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
