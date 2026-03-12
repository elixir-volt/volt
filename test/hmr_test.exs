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

    test "handles update messages" do
      js = Volt.HMR.Client.js()
      assert js =~ "update"
      assert js =~ "location.reload"
    end

    test "handles error overlay" do
      js = Volt.HMR.Client.js()
      assert js =~ "showOverlay"
      assert js =~ "volt-error-overlay"
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
    test "broadcasts via registry on dispatch" do
      Registry.register(Volt.HMR.Registry, :clients, nil)

      Registry.dispatch(Volt.HMR.Registry, :clients, fn entries ->
        for {pid, _} <- entries do
          send(pid, {:volt_hmr, :update, %{path: "test.ts", changes: [:full]}})
        end
      end)

      assert_receive {:volt_hmr, :update, %{path: "test.ts", changes: [:full]}}
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
