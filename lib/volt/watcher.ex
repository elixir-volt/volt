defmodule Volt.Watcher do
  @moduledoc """
  File watcher that triggers recompilation, Tailwind rebuilds, and HMR updates.

  Monitors source directories for changes, recompiles affected JS/Vue/CSS
  files through the Pipeline, triggers Tailwind CSS rebuilds when template
  files change, and broadcasts updates to connected HMR clients.

  When a JS/TS/Vue file changes, the watcher attempts to find an HMR boundary
  (a module with `import.meta.hot.accept()`) by walking up the dependency
  graph. If found, only that module is re-imported by the client. Otherwise,
  a full page reload is triggered. Files added to or removed from
  `import.meta.glob()` patterns invalidate the module that owns the glob.

  ## Options

    * `:root` — asset source directory (required, e.g. `"assets"`)
    * `:watch_dirs` — additional directories to watch for Tailwind scanning
      (e.g. `["lib/"]` for `.ex`/`.heex` templates)
    * `:reload_dirs` — additional directories whose changes trigger a full
      browser reload without being compiled by Volt
    * `:tailwind` — enable Tailwind CSS rebuilds (default: `false`)
    * `:tailwind_css` — custom Tailwind input CSS (default: Tailwind base)
    * `:target` — JS downlevel target
    * `:import_source` — JSX import source
    * `:vapor` — Vue Vapor mode
  """
  use GenServer
  require Logger

  alias Volt.HMR
  alias Volt.HMR.StyleGraph
  alias Volt.JS.Extensions

  @dialyzer {:nowarn_function, detect_changes: 2}

  @debounce_ms 50
  @tailwind_debounce_ms 100

  @write_events [:created, :modified, :closed, :deleted, :removed, :renamed]

  defstruct [
    :root,
    :config,
    fs_pids: [],
    pending: %{},
    tailwind_timer: nil,
    tailwind_changed: [],
    tailwind_full?: false,
    tailwind_outdir: nil,
    tailwind_dirs: [],
    reload_dirs: []
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    root = Keyword.fetch!(opts, :root) |> Path.expand()
    watch_dirs = Keyword.get(opts, :watch_dirs, []) |> Enum.map(&Path.expand/1)
    reload_dirs = Keyword.get(opts, :reload_dirs, []) |> Enum.map(&Path.expand/1)
    tailwind_outdir = Keyword.get(opts, :tailwind_outdir) |> maybe_expand()

    config =
      opts
      |> Keyword.drop([:root, :name, :watch_dirs, :reload_dirs, :tailwind_outdir])
      |> Map.new()

    all_dirs = Enum.uniq([root | watch_dirs ++ reload_dirs ++ tailwind_colocated_dirs(config)])

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
      tailwind_outdir: tailwind_outdir,
      tailwind_dirs: all_dirs,
      reload_dirs: reload_dirs
    }

    if config[:tailwind] do
      initial_tailwind_build(all_dirs, config[:tailwind_css], tailwind_outdir)
    end

    {:ok, state}
  end

  defp initial_tailwind_build(dirs, css_path, outdir) do
    case build_tailwind(dirs, css_path, outdir) do
      {:ok, css} ->
        Logger.debug("[Volt] Initial Tailwind build: #{byte_size(css)} bytes")

      {:error, reason} ->
        Logger.warning("[Volt] Initial Tailwind build failed: #{inspect(reason)}")
    end
  end

  defp build_tailwind(dirs, css_path, outdir) do
    sources = Enum.map(dirs, &%{base: &1, pattern: "**/*"})

    {css_input, css_base} =
      if css_path do
        {File.read!(css_path), Path.dirname(css_path)}
      else
        {nil, File.cwd!()}
      end

    with {:ok, css} <- Volt.Tailwind.build(sources: sources, css: css_input, css_base: css_base) do
      if outdir do
        File.mkdir_p!(outdir)
        File.write!(Path.join(outdir, "app.css"), css)
      end

      {:ok, css}
    end
  end

  @impl true
  def handle_info({:file_event, _pid, {path, events}}, state) do
    if relevant_write_event?(events) do
      ext = Path.extname(path)

      cond do
        ext in Extensions.watchable_js(state.config[:plugins] || []) ->
          state = schedule_rebuild(state, path)
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        ext in Extensions.css() ->
          state = handle_css_change(path, state)
          {:noreply, state}

        Volt.Assets.asset?(path) ->
          handle_asset_change(path, state)
          {:noreply, state}

        ext in Extensions.template() and state.config[:tailwind] ->
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        reload_path?(path, state) ->
          handle_reload_change(path)
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
    full? = state.tailwind_full?
    state = %{state | tailwind_timer: nil, tailwind_changed: [], tailwind_full?: false}
    handle_tailwind_rebuild(changed, full?, state)
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

  defp maybe_schedule_tailwind(state, path, opts \\ []) do
    if state.config[:tailwind] do
      if state.tailwind_timer, do: Process.cancel_timer(state.tailwind_timer)
      timer = Process.send_after(self(), :tailwind_rebuild, @tailwind_debounce_ms)

      %{
        state
        | tailwind_timer: timer,
          tailwind_changed: [path | state.tailwind_changed],
          tailwind_full?: state.tailwind_full? or Keyword.get(opts, :full?, false)
      }
    else
      state
    end
  end

  defp handle_js_change(path, state) do
    relative = Path.relative_to(path, state.root)
    css? = css_file?(path)
    css_dependents = if css?, do: Volt.HMR.StyleGraph.dependents(path), else: []

    old_entry = Volt.Cache.get_file(path)
    Volt.Cache.evict_file(path)
    Volt.HMR.ModuleGraph.invalidate_file(path)

    case File.read(path) do
      {:ok, source} ->
        case Volt.Pipeline.compile(path, source, Map.to_list(state.config)) do
          {:ok, result} ->
            Volt.HMR.GlobGraph.update_from_source(path, source)
            Volt.HMR.ImportGraph.update_from_compiled(path, result.code)

            Volt.HMR.StyleDependencies.update_from_compile(path, source, result)

            changes = if css?, do: [:style], else: detect_changes(old_entry, result)
            broadcast_change(path, relative, changes, state.root)
            broadcast_css_dependents(css_dependents, state.root)
            broadcast_glob_dependents(path, state.root)

          {:error, reason} ->
            HMR.broadcast(:error, %{path: relative, reason: reason})
        end

      {:error, reason} when reason in [:enoent, :eacces, :eperm] ->
        Volt.HMR.ImportGraph.remove(path)
        Volt.HMR.GlobGraph.remove(path)
        if css?, do: Volt.HMR.StyleGraph.remove(path)
        Volt.HMR.ModuleGraph.remove_file(path)
        HMR.update(relative, [:full])
        broadcast_glob_dependents(path, state.root)

      {:error, reason} ->
        HMR.broadcast(:error, %{path: relative, reason: inspect(reason)})
    end
  end

  defp css_file?(path), do: Path.extname(path) == ".css"

  defp handle_css_change(path, state) do
    relative = Path.relative_to(path, state.root)
    css_dependents = StyleGraph.dependents(path)

    Volt.Cache.evict_file(path)
    Volt.HMR.ModuleGraph.invalidate_file(path)

    if File.regular?(path) do
      source = File.read!(path)
      StyleGraph.update(path, Volt.CSS.Dependencies.resolve(source, path))
    else
      StyleGraph.remove(path)
    end

    if Volt.Path.inside?(path, state.root) do
      HMR.broadcast(:update, %{path: relative, changes: [:style]})
      broadcast_css_dependents(css_dependents, state.root)
      broadcast_glob_dependents(path, state.root)
    end

    maybe_schedule_tailwind(state, path, full?: true)
  end

  defp broadcast_css_dependents(dependents, root) do
    dependents
    |> Enum.uniq()
    |> Enum.each(fn importer ->
      Volt.Cache.evict_file(importer)
      Volt.HMR.ModuleGraph.invalidate_file(importer)
      relative = Path.relative_to(importer, root)
      HMR.broadcast(:update, %{path: relative, changes: [:style]})
    end)
  end

  defp handle_reload_change(path) do
    path = Path.relative_to_cwd(path)
    HMR.full_reload(path)
  end

  defp handle_asset_change(path, state) do
    relative = Path.relative_to(path, state.root)
    css_dependents = Volt.HMR.StyleGraph.dependents(path)

    Volt.Cache.evict_file(path)
    Volt.HMR.ModuleGraph.invalidate_file(path)
    HMR.broadcast(:update, %{path: relative, changes: [:full]})
    broadcast_css_dependents(css_dependents, state.root)
    broadcast_glob_dependents(path, state.root)
  end

  defp broadcast_glob_dependents(path, root) do
    path
    |> Volt.HMR.GlobGraph.dependents()
    |> Enum.reject(&(&1 == path))
    |> Enum.each(fn importer ->
      Volt.Cache.evict_file(importer)
      relative = Path.relative_to(importer, root)
      HMR.broadcast(:update, %{path: relative, changes: [:full]})
    end)
  end

  defp broadcast_change(path, relative, changes, root) do
    cond do
      changes == [:style] ->
        HMR.broadcast(:update, %{path: relative, changes: [:style]})

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

            HMR.broadcast(:update, %{
              path: relative,
              changes: [:hmr],
              boundary: boundary_relative,
              timestamp: timestamp
            })

          :full_reload ->
            HMR.broadcast(:update, %{path: relative, changes: changes})
        end
    end
  end

  defp handle_tailwind_rebuild(_changed_paths, true, state) do
    case build_tailwind(state.tailwind_dirs, state.config[:tailwind_css], state.tailwind_outdir) do
      {:ok, css} ->
        HMR.broadcast(:update, %{path: "assets/css/app.css", changes: [:style]})
        Logger.debug("[Volt] Tailwind rebuilt (#{byte_size(css)} bytes)")

      {:error, reason} ->
        HMR.broadcast(:error, %{path: "tailwind", reason: inspect(reason)})
    end
  end

  defp handle_tailwind_rebuild(changed_paths, false, state) do
    changed =
      Enum.map(changed_paths, fn path ->
        ext = path |> Path.extname() |> String.trim_leading(".")
        %{file: path, extension: ext}
      end)

    {css_input, css_base} =
      case state.config[:tailwind_css] do
        nil -> {nil, File.cwd!()}
        path -> {File.read!(path), Path.dirname(path)}
      end

    case Volt.Tailwind.rebuild(changed, css: css_input, css_base: css_base) do
      {:ok, css} ->
        if outdir = state.tailwind_outdir do
          File.mkdir_p!(outdir)
          File.write!(Path.join(outdir, "app.css"), css)
        end

        HMR.broadcast(:update, %{path: "assets/css/app.css", changes: [:style]})
        Logger.debug("[Volt] Tailwind rebuilt (#{byte_size(css)} bytes)")

      :unchanged ->
        :ok

      {:error, reason} ->
        HMR.broadcast(:error, %{path: "tailwind", reason: inspect(reason)})
    end
  end

  defp detect_changes(nil, _new), do: [:full]

  defp detect_changes(old_entry, new_result) do
    if new_result.hashes && old_entry.hashes do
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

  defp reload_path?(path, state) do
    Enum.any?(state.reload_dirs, &Volt.Path.inside?(path, &1))
  end

  defp tailwind_colocated_dirs(%{tailwind: true}) do
    if Code.ensure_loaded?(Mix.Project) do
      path = Path.join(Mix.Project.build_path(), "phoenix-colocated")
      File.mkdir_p!(path)
      [Path.expand(path)]
    else
      []
    end
  end

  defp tailwind_colocated_dirs(_config), do: []

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.fs_pids, &GenServer.stop/1)
    :ok
  end

  defp maybe_expand(nil), do: nil
  defp maybe_expand(path), do: Path.expand(path)
end
