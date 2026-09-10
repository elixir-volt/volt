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
    * `:watch_ignored` — paths or glob patterns excluded from watcher events
      (default: common VCS, dependency, test-output, cache, and build directories)
    * `:tailwind` — enable Tailwind CSS rebuilds (default: `false`)
    * `:tailwind_css` — custom Tailwind input CSS (default: Tailwind base)
    * `:tailwind_sources` — source globs scanned for Tailwind candidates
    * `:tailwind_name` — logical Tailwind output name (default: input basename)
    * `:tailwind_url` — browser URL broadcast for Tailwind style updates
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
    :configuration_signature,
    :owner_monitor,
    :managed_key,
    :tables,
    session: :default,
    fs_pids: [],
    pending: %{},
    tailwind_timer: nil,
    pending_reloads: [],
    tailwind_changed: [],
    tailwind_full?: false,
    tailwind_outdir: nil,
    discovered_watches: %{},
    base_watch_dirs: [],
    tailwind_dirs: [],
    reload_dirs: [],
    explicit_ignored: [],
    watch_ignored: []
  ]

  def start_link(opts) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    owner_monitor =
      case Keyword.get(opts, :owner) do
        nil -> nil
        owner when is_pid(owner) -> Process.monitor(owner)
      end

    root = Keyword.fetch!(opts, :root) |> Path.expand()
    watch_dirs = Keyword.get(opts, :watch_dirs, []) |> Enum.map(&Path.expand/1)
    reload_dirs = Keyword.get(opts, :reload_dirs, []) |> Enum.map(&Path.expand/1)
    tailwind_outdir = Keyword.get(opts, :tailwind_outdir) |> maybe_expand()
    tailwind_name = Keyword.get(opts, :tailwind_name, "app")
    tailwind_url = Keyword.get(opts, :tailwind_url, "/assets/css/#{tailwind_name}.css")
    session = Keyword.get(opts, :session, :default)
    tailwind_key = Keyword.get(opts, :tailwind_key, {:watcher, root})

    tailwind_key =
      if session == :default, do: tailwind_key, else: {:session, session, tailwind_key}

    configured_tailwind_sources = Keyword.get(opts, :tailwind_sources)

    config =
      opts
      |> Keyword.drop([
        :root,
        :name,
        :session,
        :owner,
        :managed_key,
        :tables,
        :watch_dirs,
        :reload_dirs,
        :watch_ignored,
        :tailwind_key,
        :tailwind_name,
        :tailwind_sources,
        :tailwind_url,
        :tailwind_outdir
      ])
      |> Map.new()

    source_dirs =
      if config[:tailwind] do
        Enum.map(configured_tailwind_sources || [], &Path.expand(&1.base))
      else
        []
      end

    all_dirs =
      Enum.uniq([
        root | watch_dirs ++ reload_dirs ++ source_dirs ++ tailwind_colocated_dirs(config)
      ])

    tailwind_sources = configured_tailwind_sources || watcher_sources(all_dirs)
    watch_ignored = Volt.Watcher.Ignore.compile(Keyword.get(opts, :watch_ignored, []), all_dirs)

    fs_pids =
      Enum.map(all_dirs, fn dir ->
        {:ok, pid} = FileSystem.start_link(dirs: [dir])
        FileSystem.subscribe(pid)
        pid
      end)

    config =
      config
      |> Map.put(:tailwind_key, tailwind_key)
      |> Map.put(:tailwind_name, tailwind_name)
      |> Map.put(:tailwind_configured_sources, tailwind_sources)
      |> Map.put(:tailwind_sources, tailwind_sources)
      |> Map.put(:tailwind_url, tailwind_url)

    state = %__MODULE__{
      root: root,
      owner_monitor: owner_monitor,
      tables: Keyword.get(opts, :tables),
      managed_key: Keyword.get(opts, :managed_key),
      configuration_signature:
        Keyword.get(
          opts,
          :configuration_signature,
          opts |> Keyword.drop([:name, :managed_key]) |> Map.new()
        ),
      session: Keyword.get(opts, :session, :default),
      fs_pids: fs_pids,
      config: config,
      tailwind_outdir: tailwind_outdir,
      base_watch_dirs: all_dirs,
      tailwind_dirs: all_dirs,
      reload_dirs: reload_dirs,
      explicit_ignored:
        Volt.Watcher.Ignore.compile_explicit(Keyword.get(opts, :watch_ignored, []), all_dirs),
      watch_ignored: watch_ignored
    }

    if config[:tailwind] do
      initial_tailwind_build(
        tailwind_sources,
        config[:tailwind_css],
        tailwind_outdir,
        tailwind_key,
        tailwind_name,
        config[:tailwind_runtime],
        config[:tailwind_worker]
      )
    end

    {:ok, refresh_tailwind_inputs(state)}
  end

  defp refresh_tailwind_inputs(%{config: %{tailwind: true, tailwind_worker: worker}} = state)
       when not is_nil(worker) do
    inputs = Volt.Tailwind.Worker.inputs(worker)

    dirs =
      Enum.uniq(
        Enum.map(inputs.sources, &Path.expand(&1.base)) ++
          Enum.map(inputs.dependencies, &Path.dirname/1)
      )

    desired =
      dirs
      |> Enum.map(&existing_watch_parent/1)
      |> Enum.uniq()
      |> Enum.reject(&(&1 in state.base_watch_dirs))

    {kept, removed} = Map.split(state.discovered_watches, desired)

    Enum.each(removed, fn {_dir, pid} ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    added =
      Map.new(desired -- Map.keys(kept), fn dir ->
        {:ok, pid} = FileSystem.start_link(dirs: [dir])
        FileSystem.subscribe(pid)
        {dir, pid}
      end)

    watches = Map.merge(kept, added)

    config =
      state.config
      |> Map.put(:tailwind_sources, inputs.sources)
      |> Map.put(:tailwind_dependencies, inputs.dependencies)

    %{
      state
      | config: config,
        discovered_watches: watches,
        fs_pids: (state.fs_pids -- Map.values(removed)) ++ Map.values(added),
        tailwind_dirs: state.base_watch_dirs ++ Map.keys(watches)
    }
  end

  defp refresh_tailwind_inputs(state), do: state

  defp existing_watch_parent(path) do
    parent = Path.dirname(path)
    if File.dir?(path) or parent == path, do: path, else: existing_watch_parent(parent)
  end

  @impl true
  def handle_call({:configuration_matches, signature}, _from, state) do
    {:reply, state.configuration_signature == signature, state}
  end

  defp watcher_sources(dirs), do: Enum.map(dirs, &%{base: &1, pattern: "**/*"})

  defp initial_tailwind_build(sources, css_path, outdir, key, name, runtime, worker) do
    case build_tailwind(sources, css_path, outdir, key, name, runtime, worker) do
      {:ok, css} ->
        Logger.debug("[Volt] Initial Tailwind build: #{byte_size(css)} bytes")

      {:error, reason} ->
        Logger.warning("[Volt] Initial Tailwind build failed: #{inspect(reason)}")
    end
  end

  defp build_tailwind(sources, css_path, outdir, key, name, runtime, worker) do
    worker_opts = if worker, do: [worker: worker], else: [key: key, runtime: runtime]

    with {:ok, {css_input, css_base}} <- read_tailwind_css(css_path),
         {:ok, css} <-
           Volt.Tailwind.build(
             worker_opts ++
               [
                 sources: sources,
                 css: css_input,
                 css_base: css_base
               ]
           ) do
      Volt.Tailwind.Artifact.write(outdir, name, css)
      {:ok, css}
    end
  end

  defp read_tailwind_css(nil), do: {:ok, {nil, File.cwd!()}}

  defp read_tailwind_css(path) do
    case File.read(path) do
      {:ok, css} -> {:ok, {css, Path.dirname(path)}}
      {:error, reason} -> {:error, {:tailwind_css, path, reason}}
    end
  end

  @impl true
  def handle_info({:file_event, _pid, {path, events}}, state) do
    path = Volt.Watcher.Path.normalize_from_roots(path, state.tailwind_dirs)

    if relevant_write_event?(events) and not ignored_path?(path, state) do
      ext = Path.extname(path)

      cond do
        tailwind_output?(path, state) ->
          {:noreply, state}

        path in Map.get(state.config, :tailwind_dependencies, []) ->
          {:noreply, maybe_schedule_tailwind(state, path, full?: true)}

        reload_path?(path, state) and state.config[:tailwind] ->
          state = %{state | pending_reloads: Enum.uniq([path | state.pending_reloads])}
          {:noreply, maybe_schedule_tailwind(state, path)}

        ext in Extensions.css() ->
          state = handle_css_change(path, state)
          {:noreply, state}

        ext in Extensions.watchable_js(state.config[:plugins] || []) ->
          state = schedule_rebuild(state, path)
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        Volt.Assets.asset?(path) ->
          handle_asset_change(path, state)
          {:noreply, state}

        ext in Extensions.template() and state.config[:tailwind] ->
          state = maybe_schedule_tailwind(state, path)
          {:noreply, state}

        reload_path?(path, state) ->
          handle_reload_change(path, state)
          {:noreply, maybe_schedule_tailwind(state, path)}

        tailwind_source?(path, state) ->
          {:noreply, maybe_schedule_tailwind(state, path)}

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

    case handle_tailwind_rebuild(changed, full?, state) do
      :ok ->
        Enum.each(state.pending_reloads, &handle_reload_change(&1, state))
        {:noreply, refresh_tailwind_inputs(%{state | pending_reloads: []})}

      {:error, _reason} ->
        {:noreply, refresh_tailwind_inputs(%{state | tailwind_full?: true})}
    end
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{owner_monitor: ref} = state)
      when is_reference(ref) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    if pid in state.fs_pids,
      do: {:stop, {:filesystem_watcher_exit, reason}, state},
      else: {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp relevant_write_event?(events) do
    Enum.any?(@write_events, &(&1 in events))
  end

  defp ignored_path?(path, state) do
    patterns =
      if path in Map.get(state.config, :tailwind_dependencies, []),
        do: state.explicit_ignored,
        else: state.watch_ignored

    Enum.any?(patterns, &GlobEx.match?(&1, path))
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

    css_dependents =
      if css?, do: Volt.HMR.StyleGraph.dependents(path, state.tables || state.session), else: []

    old_entry = Volt.Cache.get_file(path, state.tables || state.session)
    Volt.Cache.evict_file(path, state.tables || state.session)

    Volt.HMR.ModuleGraph.invalidate_file(
      path,
      System.system_time(:millisecond),
      state.tables || state.session
    )

    case File.read(path) do
      {:ok, source} ->
        case Volt.Pipeline.compile(path, source, Map.to_list(state.config)) do
          {:ok, result} ->
            Volt.HMR.GlobGraph.update_from_source(path, source, state.tables || state.session)

            Volt.HMR.ImportGraph.update_from_compiled(
              path,
              result.code,
              state.tables || state.session
            )

            Volt.HMR.StyleDependencies.update_from_compile(
              path,
              source,
              result,
              state.tables || state.session
            )

            changes = if css?, do: [:style], else: detect_changes(old_entry, result)
            broadcast_change(path, relative, changes, state)
            broadcast_css_dependents(css_dependents, state)
            broadcast_glob_dependents(path, state)

          {:error, reason} ->
            HMR.broadcast(:error, %{path: relative, reason: reason}, session: state.session)
        end

      {:error, reason} when reason in [:enoent, :eacces, :eperm] ->
        Volt.HMR.ImportGraph.remove(path, state.tables || state.session)
        Volt.HMR.GlobGraph.remove(path, state.tables || state.session)
        if css?, do: Volt.HMR.StyleGraph.remove(path, state.tables || state.session)
        Volt.HMR.ModuleGraph.remove_file(path, state.tables || state.session)
        HMR.update(relative, [:full], session: state.session)
        broadcast_glob_dependents(path, state)

      {:error, reason} ->
        HMR.broadcast(:error, %{path: relative, reason: inspect(reason)}, session: state.session)
    end
  end

  defp css_file?(path), do: Path.extname(path) == ".css"

  defp handle_css_change(path, state) do
    relative = Path.relative_to(path, state.root)
    css_dependents = StyleGraph.dependents(path, state.tables || state.session)
    tailwind_input? = tailwind_input?(path, state)

    Volt.Cache.evict_file(path, state.tables || state.session)

    Volt.HMR.ModuleGraph.invalidate_file(
      path,
      System.system_time(:millisecond),
      state.tables || state.session
    )

    if File.regular?(path) do
      source = File.read!(path)

      StyleGraph.update(
        path,
        Volt.CSS.Dependencies.resolve(source, path),
        state.tables || state.session
      )
    else
      StyleGraph.remove(path, state.tables || state.session)
    end

    if Volt.Path.inside?(path, state.root) and not tailwind_input? do
      HMR.broadcast(:update, %{path: relative, changes: [:style]}, session: state.session)
      broadcast_css_dependents(css_dependents, state)
      broadcast_glob_dependents(path, state)
    end

    maybe_schedule_tailwind(state, path, full?: true)
  end

  defp tailwind_input?(path, %{config: %{tailwind: true, tailwind_css: css}})
       when is_binary(css) do
    Path.expand(path) == Path.expand(css)
  end

  defp tailwind_input?(_path, _state), do: false

  defp tailwind_output?(_path, %{tailwind_outdir: nil}), do: false
  defp tailwind_output?(path, state), do: Volt.Path.inside?(path, state.tailwind_outdir)

  defp broadcast_css_dependents(dependents, state) do
    dependents
    |> Enum.uniq()
    |> Enum.each(fn importer ->
      Volt.Cache.evict_file(importer, state.tables || state.session)

      Volt.HMR.ModuleGraph.invalidate_file(
        importer,
        System.system_time(:millisecond),
        state.session
      )

      relative = Path.relative_to(importer, state.root)
      HMR.broadcast(:update, %{path: relative, changes: [:style]}, session: state.session)
    end)
  end

  defp handle_reload_change(path, state) do
    path = Path.relative_to_cwd(path)
    HMR.full_reload(path, session: state.session)
  end

  defp handle_asset_change(path, state) do
    relative = Path.relative_to(path, state.root)
    css_dependents = Volt.HMR.StyleGraph.dependents(path, state.tables || state.session)

    Volt.Cache.evict_file(path, state.tables || state.session)

    Volt.HMR.ModuleGraph.invalidate_file(
      path,
      System.system_time(:millisecond),
      state.tables || state.session
    )

    HMR.broadcast(:update, %{path: relative, changes: [:full]}, session: state.session)
    broadcast_css_dependents(css_dependents, state)
    broadcast_glob_dependents(path, state)
  end

  defp broadcast_glob_dependents(path, state) do
    path
    |> Volt.HMR.GlobGraph.dependents(state.tables || state.session)
    |> Enum.reject(&(&1 == path))
    |> Enum.each(fn importer ->
      Volt.Cache.evict_file(importer, state.tables || state.session)
      relative = Path.relative_to(importer, state.root)
      HMR.broadcast(:update, %{path: relative, changes: [:full]}, session: state.session)
    end)
  end

  defp broadcast_change(path, relative, changes, state) do
    cond do
      changes == [:style] ->
        HMR.broadcast(:update, %{path: relative, changes: [:style]}, session: state.session)

      changes == [] ->
        :ok

      true ->
        read_source = fn p ->
          case File.read(p) do
            {:ok, src} -> src
            _ -> nil
          end
        end

        case Volt.HMR.Boundary.find_boundary(path, read_source, state.tables || state.session) do
          {:ok, boundary_path} ->
            timestamp = System.system_time(:millisecond)
            boundary_relative = Path.relative_to(boundary_path, state.root)

            HMR.broadcast(
              :update,
              %{
                path: relative,
                changes: [:hmr],
                boundary: boundary_relative,
                timestamp: timestamp
              },
              session: state.session
            )

          :full_reload ->
            HMR.broadcast(:update, %{path: relative, changes: changes}, session: state.session)
        end
    end
  end

  defp handle_tailwind_rebuild(_changed_paths, true, state) do
    previous = previous_stylesheet(state)

    case build_tailwind(
           state.config.tailwind_configured_sources,
           state.config[:tailwind_css],
           state.tailwind_outdir,
           state.config.tailwind_key,
           state.config.tailwind_name,
           state.config[:tailwind_runtime],
           state.config[:tailwind_worker]
         ) do
      {:ok, css} ->
        if previous != {:ok, css} do
          HMR.broadcast(:update, %{path: state.config.tailwind_url, changes: [:style]},
            session: state.session
          )
        end

        Logger.debug("[Volt] Tailwind rebuilt (#{byte_size(css)} bytes)")
        :ok

      {:error, reason} ->
        tailwind_error(reason, state.session)
    end
  end

  defp handle_tailwind_rebuild(changed_paths, false, state) do
    changed =
      Enum.map(changed_paths, fn path ->
        ext = path |> Path.extname() |> String.trim_leading(".")
        %{file: path, extension: ext}
      end)

    worker_opts =
      case state.config[:tailwind_worker] do
        nil -> [key: state.config.tailwind_key]
        worker -> [worker: worker]
      end

    with {:ok, {css_input, css_base}} <- read_tailwind_css(state.config[:tailwind_css]),
         {:ok, css} <-
           Volt.Tailwind.rebuild(
             changed,
             worker_opts ++
               [
                 css: css_input,
                 css_base: css_base
               ]
           ) do
      Volt.Tailwind.Artifact.write(state.tailwind_outdir, state.config.tailwind_name, css)

      HMR.broadcast(:update, %{path: state.config.tailwind_url, changes: [:style]},
        session: state.session
      )

      Logger.debug("[Volt] Tailwind rebuilt (#{byte_size(css)} bytes)")
      :ok
    else
      :unchanged ->
        :ok

      {:error, reason} ->
        tailwind_error(reason, state.session)
    end
  end

  defp previous_stylesheet(state) do
    worker =
      state.config[:tailwind_worker] ||
        case Registry.lookup(Volt.Tailwind.Registry, state.config.tailwind_key) do
          [{pid, _}] -> pid
          [] -> nil
        end

    if worker, do: Volt.Tailwind.Worker.stylesheet(worker), else: {:error, :not_built}
  end

  defp tailwind_error(reason, session) do
    HMR.broadcast(:error, %{path: "tailwind", reason: inspect(reason)}, session: session)
    {:error, reason}
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

  defp tailwind_source?(path, state) do
    state.config[:tailwind] &&
      Enum.any?(state.config.tailwind_sources, fn source ->
        not Map.get(source, :negated, false) and
          GlobEx.match?(
            GlobEx.compile!(Path.join(Path.expand(source.base), source.pattern)),
            path
          )
      end)
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
    Enum.each(state.fs_pids, fn pid ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    if state.config[:tailwind] && is_nil(state.config[:tailwind_worker]),
      do: Volt.Tailwind.Supervisor.release(state.config.tailwind_key)

    if state.session != :default, do: Volt.Dev.State.clear(state.session)
    if state.managed_key, do: Registry.unregister(Volt.Dev.WatcherRegistry, state.managed_key)
    :ok
  end

  defp maybe_expand(nil), do: nil
  defp maybe_expand(path), do: Path.expand(path)
end
