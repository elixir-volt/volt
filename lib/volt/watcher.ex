defmodule Volt.Watcher do
  @moduledoc """
  File watcher that triggers recompilation, Tailwind rebuilds, and HMR updates.

  Monitors source directories for changes, recompiles affected JS/Vue/CSS
  files through the Pipeline, triggers Tailwind CSS rebuilds when template
  files change, and broadcasts updates to connected HMR clients.

  When a JS/TS/Vue file changes, the watcher attempts to find an HMR boundary
  (a module with `import.meta.hot.accept()`) by walking up the dependency
  graph. If found, only that module is re-imported by the client. Otherwise,
  a full page reload is triggered.

  ## Options

    * `:root` — asset source directory (required, e.g. `"assets"`)
    * `:watch_dirs` — additional directories to watch for Tailwind scanning
      (e.g. `["lib/"]` for `.ex`/`.heex` templates)
    * `:tailwind` — enable Tailwind CSS rebuilds (default: `false`)
    * `:tailwind_css` — custom Tailwind input CSS (default: Tailwind base)
    * `:target` — JS downlevel target
    * `:import_source` — JSX import source
    * `:vapor` — Vue Vapor mode
  """
  use GenServer
  require Logger

  @dialyzer {:nowarn_function, update_dep_graph: 2, detect_changes: 2}

  @debounce_ms 50
  @tailwind_debounce_ms 100

  @write_events [:created, :modified, :closed]

  defstruct [
    :root,
    :config,
    fs_pids: [],
    pending: %{},
    tailwind_timer: nil,
    tailwind_changed: [],
    tailwind_outdir: nil
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    root = Keyword.fetch!(opts, :root) |> Path.expand()
    watch_dirs = Keyword.get(opts, :watch_dirs, []) |> Enum.map(&Path.expand/1)
    tailwind_outdir = Keyword.get(opts, :tailwind_outdir) |> maybe_expand()

    config =
      opts
      |> Keyword.drop([:root, :name, :watch_dirs, :tailwind_outdir])
      |> Map.new()

    all_dirs = Enum.uniq([root | watch_dirs])

    fs_pids =
      Enum.map(all_dirs, fn dir ->
        {:ok, pid} = FileSystem.start_link(dirs: [dir])
        FileSystem.subscribe(pid)
        pid
      end)

    state = %__MODULE__{
      root: root,
      fs_pids: fs_pids,
      config: config,
      tailwind_outdir: tailwind_outdir
    }

    if config[:tailwind] do
      initial_tailwind_build(all_dirs, config[:tailwind_css], tailwind_outdir)
    end

    {:ok, state}
  end

  defp initial_tailwind_build(dirs, css_path, outdir) do
    sources =
      Enum.map(dirs, fn dir ->
        %{base: dir, pattern: "**/*"}
      end)

    css_input = if css_path, do: File.read!(css_path)

    case Volt.Tailwind.build(sources: sources, css: css_input) do
      {:ok, css} ->
        if outdir do
          File.mkdir_p!(outdir)
          File.write!(Path.join(outdir, "app.css"), css)
        end

        Logger.debug("[Volt] Initial Tailwind build: #{byte_size(css)} bytes")

      {:error, reason} ->
        Logger.warning("[Volt] Initial Tailwind build failed: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_info({:file_event, _pid, {path, events}}, state) do
    if relevant_write_event?(events) do
      ext = Path.extname(path)

      cond do
        ext in Volt.Extensions.watchable_js() ->
          state = schedule_rebuild(state, path)
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        ext in Volt.Extensions.template() and state.config[:tailwind] ->
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        true ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:rebuild, path}, state) do
    state = %{state | pending: Map.delete(state.pending, path)}
    handle_js_change(path, state)
    {:noreply, state}
  end

  def handle_info(:tailwind_rebuild, state) do
    changed = state.tailwind_changed
    state = %{state | tailwind_timer: nil, tailwind_changed: []}
    handle_tailwind_rebuild(changed, state)
    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp relevant_write_event?(events) do
    Enum.any?(@write_events, &(&1 in events))
  end

  defp schedule_rebuild(state, path) do
    case Map.get(state.pending, path) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    ref = Process.send_after(self(), {:rebuild, path}, @debounce_ms)
    %{state | pending: Map.put(state.pending, path, ref)}
  end

  defp maybe_schedule_tailwind(state, path) do
    if state.config[:tailwind] do
      if state.tailwind_timer, do: Process.cancel_timer(state.tailwind_timer)
      timer = Process.send_after(self(), :tailwind_rebuild, @tailwind_debounce_ms)

      %{state | tailwind_timer: timer, tailwind_changed: [path | state.tailwind_changed]}
    else
      state
    end
  end

  defp handle_js_change(path, state) do
    relative = Path.relative_to(path, state.root)

    old_mtime = Volt.Format.file_mtime(path)
    old_entry = Volt.Cache.get(path, old_mtime)
    Volt.Cache.evict(path)

    case File.read(path) do
      {:ok, source} ->
        case Volt.Pipeline.compile(path, source, Map.to_list(state.config)) do
          {:ok, result} ->
            mtime = Volt.Format.file_mtime(path)

            entry = %{
              code: result.code,
              sourcemap: result.sourcemap,
              css: result.css,
              hashes: result.hashes,
              content_type: "application/javascript"
            }

            Volt.Cache.put(path, mtime, entry)
            update_dep_graph(path, result.code)

            changes = detect_changes(old_entry, result)
            broadcast_change(path, relative, changes, state.root)

          {:error, reason} ->
            broadcast(:error, %{path: relative, reason: reason})
        end

      {:error, :enoent} ->
        Volt.Cache.evict(path)
        Volt.DepGraph.remove(path)
        broadcast(:remove, %{path: relative})
    end
  end

  defp broadcast_change(path, relative, changes, root) do
    cond do
      changes == [:style] ->
        broadcast(:update, %{path: relative, changes: [:style]})

      changes == [] ->
        :ok

      true ->
        read_source = fn p ->
          case File.read(p) do
            {:ok, src} -> src
            _ -> nil
          end
        end

        case Volt.HMR.Boundary.find_boundary(path, read_source) do
          {:ok, boundary_path} ->
            timestamp = System.system_time(:millisecond)
            boundary_relative = Path.relative_to(boundary_path, root)

            broadcast(:update, %{
              path: relative,
              changes: [:hmr],
              boundary: boundary_relative,
              timestamp: timestamp
            })

          :full_reload ->
            broadcast(:update, %{path: relative, changes: changes})
        end
    end
  end

  defp handle_tailwind_rebuild(changed_paths, state) do
    changed =
      Enum.map(changed_paths, fn path ->
        ext = path |> Path.extname() |> String.trim_leading(".")
        %{file: path, extension: ext}
      end)

    css_input =
      case state.config[:tailwind_css] do
        nil -> nil
        path -> File.read!(path)
      end

    case Volt.Tailwind.rebuild(changed, css: css_input) do
      {:ok, css} ->
        if outdir = state.tailwind_outdir do
          File.mkdir_p!(outdir)
          File.write!(Path.join(outdir, "app.css"), css)
        end

        broadcast(:update, %{path: "assets/css/app.css", changes: [:style]})
        Logger.debug("[Volt] Tailwind rebuilt (#{byte_size(css)} bytes)")

      :unchanged ->
        :ok

      {:error, reason} ->
        broadcast(:error, %{path: "tailwind", reason: inspect(reason)})
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
    if new_result.hashes && old_entry[:hashes] do
      old_h = old_entry.hashes
      new_h = new_result.hashes
      changes = []
      changes = if old_h.template != new_h.template, do: [:template | changes], else: changes
      changes = if old_h.style != new_h.style, do: [:style | changes], else: changes
      changes = if old_h.script != new_h.script, do: [:script | changes], else: changes
      if changes == [], do: [], else: changes
    else
      [:full]
    end
  end

  defp broadcast(type, payload) do
    Registry.dispatch(Volt.HMR.Registry, :clients, fn entries ->
      msg = {:volt_hmr, type, payload}
      for {pid, _} <- entries, do: send(pid, msg)
    end)
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.fs_pids, &GenServer.stop/1)
    :ok
  end

  defp maybe_expand(nil), do: nil
  defp maybe_expand(path), do: Path.expand(path)
end
