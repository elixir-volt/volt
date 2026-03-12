defmodule Volt.Watcher do
  @moduledoc """
  File watcher that triggers recompilation and HMR updates.

  Monitors a source directory for changes, recompiles affected files
  through the Pipeline, compares content hashes for Vue SFCs, and
  broadcasts updates to connected HMR clients.
  """
  use GenServer
  require Logger

  @debounce_ms 50

  defstruct [:root, :fs_pid, :config, pending: %{}]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Subscribe the calling process to HMR events."
  @spec subscribe :: :ok
  def subscribe(server \\ __MODULE__) do
    GenServer.call(server, {:subscribe, self()})
  end

  @impl true
  def init(opts) do
    root = Keyword.fetch!(opts, :root) |> Path.expand()
    config = Map.new(Keyword.drop(opts, [:root, :name]))

    {:ok, pid} = FileSystem.start_link(dirs: [root])
    FileSystem.subscribe(pid)
    Volt.Cache.init()
    Volt.DepGraph.init()

    {:ok, %__MODULE__{root: root, fs_pid: pid, config: config}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:file_event, _pid, {path, events}}, state) do
    if compilable?(path) and :modified in events do
      state = schedule_rebuild(state, path)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:rebuild, path}, state) do
    state = %{state | pending: Map.delete(state.pending, path)}
    handle_file_change(path, state)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp schedule_rebuild(state, path) do
    case Map.get(state.pending, path) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    ref = Process.send_after(self(), {:rebuild, path}, @debounce_ms)
    %{state | pending: Map.put(state.pending, path, ref)}
  end

  defp handle_file_change(path, state) do
    relative = Path.relative_to(path, state.root)

    old_entry = Volt.Cache.get(path, 0)
    Volt.Cache.evict(path)

    case File.read(path) do
      {:ok, source} ->
        case Volt.Pipeline.compile(path, source, Map.to_list(state.config)) do
          {:ok, result} ->
            mtime = file_mtime(path)

            entry = %{
              code: result.code,
              sourcemap: result.sourcemap,
              css: result.css,
              content_type: "application/javascript"
            }

            Volt.Cache.put(path, mtime, entry)

            update_dep_graph(path, result.code)
            changes = detect_changes(old_entry, result)
            broadcast_update(relative, changes)

          {:error, reason} ->
            broadcast_error(relative, reason)
        end

      {:error, :enoent} ->
        Volt.Cache.evict(path)
        Volt.DepGraph.remove(path)
        broadcast_remove(relative)
    end
  end

  defp update_dep_graph(path, code) do
    case OXC.imports(code, Path.basename(path)) do
      {:ok, imports} -> Volt.DepGraph.update(path, imports)
      _ -> :ok
    end
  end

  defp detect_changes(nil, _new), do: [:full]

  defp detect_changes(old_entry, new_result) do
    cond do
      new_result.hashes && old_entry[:hashes] ->
        old_h = old_entry.hashes
        new_h = new_result.hashes
        changes = []
        changes = if old_h.template != new_h.template, do: [:template | changes], else: changes
        changes = if old_h.style != new_h.style, do: [:style | changes], else: changes
        changes = if old_h.script != new_h.script, do: [:script | changes], else: changes
        if changes == [], do: [], else: changes

      true ->
        [:full]
    end
  end

  defp broadcast_update(path, changes) do
    msg = {:volt_hmr, :update, %{path: path, changes: changes}}
    dispatch(msg)
  end

  defp broadcast_error(path, reason) do
    msg = {:volt_hmr, :error, %{path: path, reason: reason}}
    dispatch(msg)
  end

  defp broadcast_remove(path) do
    msg = {:volt_hmr, :remove, %{path: path}}
    dispatch(msg)
  end

  defp dispatch(msg) do
    Registry.dispatch(Volt.HMR.Registry, :clients, fn entries ->
      for {pid, _} <- entries, do: send(pid, msg)
    end)
  end

  @compilable_exts ~w(.vue .ts .tsx .js .jsx .mts .mjs .css)
  defp compilable?(path), do: Path.extname(path) in @compilable_exts

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> 0
    end
  end
end
