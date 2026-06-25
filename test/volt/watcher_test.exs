defmodule Volt.WatcherTest do
  use ExUnit.Case, async: false

  setup %{test: test_name} do
    watch_dir = Path.expand("fixtures/watcher_test/#{test_name}", __DIR__)
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
end
