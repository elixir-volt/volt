defmodule Volt.WatcherTest do
  use ExUnit.Case, async: false

  setup %{test: test_name} do
    watch_dir =
      Path.expand(Path.join("volt-watcher-test", to_string(test_name)), System.tmp_dir!())

    File.mkdir_p!(watch_dir)
    Volt.HMR.ImportGraph.clear()
    Volt.Cache.clear()
    on_exit(fn -> File.rm_rf!(watch_dir) end)
    {:ok, watch_dir: watch_dir}
  end

  test "broadcasts via registry on dispatch" do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    Registry.dispatch(Volt.HMR.Registry, :clients, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:volt_hmr, :update, %{path: "test.ts", changes: [:full]}})
      end
    end)

    assert_receive {:volt_hmr, :update, %{path: "test.ts", changes: [:full]}}
  end

  test "starts and watches a directory", %{watch_dir: watch_dir} do
    {:ok, pid} = Volt.Watcher.start_link(root: watch_dir, name: :test_watcher)
    assert Process.alive?(pid)
    GenServer.stop(pid)
  end

  test "stays alive when the configured Tailwind stylesheet is missing", %{
    watch_dir: watch_dir
  } do
    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        name: :test_watcher_missing_tailwind,
        tailwind: true,
        tailwind_css: Path.join(watch_dir, "missing.css")
      )

    assert Process.alive?(pid)
    GenServer.stop(pid)
  end

  test "detects file changes and broadcasts update", %{watch_dir: watch_dir} do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    ts_file = Path.join(watch_dir, "app.ts")
    File.write!(ts_file, "export const x = 1;")

    {:ok, pid} = Volt.Watcher.start_link(root: watch_dir, name: :test_watcher_change)

    Process.sleep(100)
    File.write!(ts_file, "export const x = 2;")

    assert_receive {:volt_hmr, :update, %{path: "app.ts", changes: [:full]}}, 2000

    GenServer.stop(pid)
  end

  test "ignores configured watcher paths", %{watch_dir: watch_dir} do
    generated_dir = Path.join(watch_dir, ".generated")
    entry = Path.join(generated_dir, "entry.ts")
    File.mkdir_p!(generated_dir)

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        watch_ignored: [Path.join(generated_dir, "**")],
        name: :test_watcher_ignored
      )

    state = send_file_event(pid, entry)

    refute Map.has_key?(state.pending, entry)
    GenServer.stop(pid)
  end

  test "does not ignore sibling watcher paths", %{watch_dir: watch_dir} do
    generated_dir = Path.join(watch_dir, ".generated")
    source_file = Path.join([watch_dir, "source", "entry.ts"])
    File.mkdir_p!(Path.dirname(source_file))
    File.write!(source_file, "export const value = 1")

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        watch_ignored: [Path.join(generated_dir, "**")],
        name: :test_watcher_ignored_sibling
      )

    state = send_file_event(pid, source_file)

    assert Map.has_key?(state.pending, source_file)
    Process.cancel_timer(state.pending[source_file])
    GenServer.stop(pid)
  end

  test "supports relative watcher ignore globs", %{watch_dir: watch_dir} do
    entry = Path.join([watch_dir, ".generated", "entry.ts"])

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        watch_ignored: ["**/.generated/**"],
        name: :test_watcher_relative_ignore
      )

    state = send_file_event(pid, entry)

    refute Map.has_key?(state.pending, entry)
    GenServer.stop(pid)
  end

  test "ignores dependency directories by default", %{watch_dir: watch_dir} do
    entry = Path.join([watch_dir, "node_modules", "example", "index.ts"])

    {:ok, pid} =
      Volt.Watcher.start_link(root: watch_dir, name: :test_watcher_default_ignored)

    state = send_file_event(pid, entry)

    refute Map.has_key?(state.pending, entry)
    GenServer.stop(pid)
  end

  test "detects asset changes and broadcasts reload update", %{watch_dir: watch_dir} do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    File.mkdir_p!(Path.join(watch_dir, "images"))
    asset_file = Path.join(watch_dir, "images/logo.svg")
    File.write!(asset_file, "<svg></svg>")

    {:ok, pid} = Volt.Watcher.start_link(root: watch_dir, name: :test_watcher_asset_change)

    Process.sleep(100)
    File.write!(asset_file, "<svg><circle /></svg>")

    assert_receive {:volt_hmr, :update, %{path: "images/logo.svg", changes: [:full]}}, 2000

    GenServer.stop(pid)
  end

  test "invalidates import.meta.glob importers when matching files are added", %{
    watch_dir: watch_dir
  } do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    File.mkdir_p!(Path.join(watch_dir, "pages"))
    routes_file = Path.join(watch_dir, "routes.ts")

    File.write!(routes_file, """
    export const pages = import.meta.glob('./pages/*.ts')
    """)

    dev_config = Volt.DevServer.init(root: watch_dir, prefix: "/assets")
    Plug.Test.conn(:get, "/assets/routes.ts") |> Volt.DevServer.call(dev_config)

    {:ok, pid} = Volt.Watcher.start_link(root: watch_dir, name: :test_watcher_glob_add)

    Process.sleep(100)
    File.write!(Path.join(watch_dir, "pages/home.ts"), "export const page = 'home'")

    assert_receive {:volt_hmr, :update, %{path: "routes.ts", changes: [:full]}}, 2000

    GenServer.stop(pid)
  end

  test "reload_dirs trigger full browser reloads for non-asset source files", %{
    watch_dir: watch_dir
  } do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    asset_dir = Path.join(watch_dir, "assets")
    content_dir = Path.join(watch_dir, "content")
    File.mkdir_p!(asset_dir)
    File.mkdir_p!(content_dir)
    page = Path.join(content_dir, "hello.md")
    File.write!(page, "# Hello")

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: asset_dir,
        reload_dirs: [content_dir],
        name: :test_watcher_reload_dirs
      )

    Process.sleep(100)
    File.write!(page, "# Updated")

    assert_receive {:volt_hmr, :update, %{path: path, changes: ["full"]}}, 2000
    assert path == Path.relative_to_cwd(page)

    GenServer.stop(pid)
  end

  test "rebuilds the Tailwind input before broadcasting its style update", %{
    watch_dir: watch_dir
  } do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    css_file = Path.join(watch_dir, "app.css")
    outdir = Path.join(watch_dir, "css_out")
    File.write!(css_file, "@import \"tailwindcss\";\n.original { color: red; }")

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        tailwind: true,
        tailwind_css: css_file,
        tailwind_outdir: outdir,
        name: :test_watcher_tw_input_css
      )

    Process.sleep(100)
    File.write!(css_file, "@import \"tailwindcss\";\n.updated { color: blue; }")

    refute_receive {:volt_hmr, :update, %{path: "app.css", changes: [:style]}}, 50

    assert_receive {:volt_hmr, :update, %{path: "assets/css/app.css", changes: [:style]}},
                   3000

    assert File.regular?(Path.join(outdir, "app.css"))
    GenServer.stop(pid)
  end

  test "triggers full Tailwind rebuild on imported CSS changes", %{watch_dir: watch_dir} do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    css_file = Path.join(watch_dir, "app.css")
    imported_css = Path.join(watch_dir, "imported.css")
    outdir = Path.join(watch_dir, "css_out")

    File.write!(css_file, "@import \"./imported.css\";\n@import \"tailwindcss\";")
    File.write!(imported_css, ".imported-card { color: rgb(34 197 94); }")

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        tailwind: true,
        tailwind_css: css_file,
        tailwind_outdir: outdir,
        name: :test_watcher_tw_imported_css
      )

    Process.sleep(100)
    File.write!(imported_css, ".imported-card { color: rgb(239 68 68); }")

    assert_receive {:volt_hmr, :update, %{path: "assets/css/app.css", changes: [:style]}},
                   3000

    css = File.read!(Path.join(outdir, "app.css"))
    assert css =~ ".imported-card"
    assert css =~ "rgb(239 68 68)"

    GenServer.stop(pid)
  end

  test "triggers tailwind rebuild on template changes", %{watch_dir: watch_dir} do
    Registry.register(Volt.HMR.Registry, :clients, nil)

    heex_file = Path.join(watch_dir, "page.heex")
    File.write!(heex_file, ~s(<div class="flex">hi</div>))

    outdir = Path.join(watch_dir, "css_out")

    {:ok, pid} =
      Volt.Watcher.start_link(
        root: watch_dir,
        watch_dirs: [watch_dir],
        tailwind: true,
        tailwind_outdir: outdir,
        name: :test_watcher_tw
      )

    Process.sleep(100)
    File.write!(heex_file, ~s(<div class="flex mt-4 bg-blue-500">hi</div>))

    assert_receive {:volt_hmr, :update, %{path: "assets/css/app.css", changes: [:style]}},
                   3000

    assert File.exists?(Path.join(outdir, "app.css"))
    css = File.read!(Path.join(outdir, "app.css"))
    assert css =~ "tailwindcss"

    GenServer.stop(pid)
  end

  defp send_file_event(pid, path) do
    :sys.replace_state(pid, fn state ->
      send(pid, {:file_event, self(), {path, [:created]}})
      state
    end)

    :sys.get_state(pid)
  end
end
