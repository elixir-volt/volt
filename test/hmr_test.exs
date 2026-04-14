defmodule Volt.HMRTest do
  use ExUnit.Case, async: false

  describe "Volt.HMR.Client" do
    test "returns JavaScript string" do
      js = Volt.HMR.Client.js()
      assert is_binary(js)
      assert js =~ "WebSocket"
      assert js =~ "@volt/ws"
      assert js =~ "HMR connected"
    end

    test "handles style-only updates without reload" do
      js = Volt.HMR.Client.js()
      assert js =~ "updateStyles"
      assert js =~ "style"
    end

    test "handles error overlay" do
      js = Volt.HMR.Client.js()
      assert js =~ "showOverlay"
      assert js =~ "volt-error-overlay"
    end

    test "reconnects on close" do
      js = Volt.HMR.Client.js()
      assert js =~ "Reconnecting"
      assert js =~ "setTimeout"
    end
  end

  describe "Volt.HMR.Socket" do
    test "init registers with registry" do
      {:ok, _state} = Volt.HMR.Socket.init(nil)
      me = self()
      assert [{^me, nil}] = Registry.lookup(Volt.HMR.Registry, :clients)
    end

    test "broadcasts HMR messages as JSON" do
      {:ok, state} = Volt.HMR.Socket.init(nil)

      {:push, {:text, json}, _state} =
        Volt.HMR.Socket.handle_info(
          {:volt_hmr, :update, %{path: "App.vue", changes: [:template]}},
          state
        )

      decoded = Jason.decode!(json)
      assert decoded["type"] == "update"
      assert decoded["payload"]["path"] == "App.vue"
      assert decoded["payload"]["changes"] == ["template"]
    end

    test "ignores unknown messages" do
      {:ok, state} = Volt.HMR.Socket.init(nil)
      assert {:ok, ^state} = Volt.HMR.Socket.handle_info(:unknown, state)
    end

    test "ignores incoming text frames" do
      {:ok, state} = Volt.HMR.Socket.init(nil)
      assert {:ok, ^state} = Volt.HMR.Socket.handle_in({"ping", opcode: :text}, state)
    end
  end

  describe "Volt.Watcher" do
    setup %{test: test_name} do
      watch_dir = Path.expand("fixtures/watcher_test/#{test_name}", __DIR__)
      File.mkdir_p!(watch_dir)
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

  describe "DevServer HMR endpoints" do
    import Plug.Test
    import Plug.Conn

    test "serves HMR client JS" do
      opts = Volt.DevServer.init(root: "/tmp")
      conn = conn(:get, "/@volt/client.js") |> Volt.DevServer.call(opts)
      assert conn.status == 200
      assert conn.resp_body =~ "WebSocket"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end
  end
end
