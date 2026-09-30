defmodule Volt.HMR.SocketTest do
  use ExUnit.Case, async: false

  setup do
    Volt.HMR.Errors.clear_session(:default)
    on_exit(fn -> Volt.HMR.Errors.clear_session(:default) end)
  end

  describe "init/1" do
    test "registers with registry" do
      {:ok, _state} = Volt.HMR.Socket.init(nil)
      me = self()
      assert {me, nil} in Registry.lookup(Volt.HMR.Registry, :clients)
    end

    test "sends current errors to a new client" do
      Volt.HMR.error("app.ts", "boom")

      {:push, {:text, json}, _state} = Volt.HMR.Socket.init(nil)

      assert %{"type" => "error", "payload" => %{"errors" => [%{"message" => "boom"}]}} =
               Jason.decode!(json)
    end
  end

  describe "handle_info/2" do
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
  end

  describe "handle_in/2" do
    test "replies to heartbeat pings with a JSON pong" do
      {:ok, state} = Volt.HMR.Socket.init(nil)

      {:push, {:text, json}, _state} =
        Volt.HMR.Socket.handle_in({~s({"type":"ping"}), opcode: :text}, state)

      decoded = Jason.decode!(json)
      assert decoded["type"] == "pong"
    end

    test "ignores unknown incoming message types" do
      {:ok, state} = Volt.HMR.Socket.init(nil)

      assert {:ok, ^state} =
               Volt.HMR.Socket.handle_in(
                 {~s({"type":"something-else"}), opcode: :text},
                 state
               )
    end

    test "ignores malformed JSON frames" do
      {:ok, state} = Volt.HMR.Socket.init(nil)
      assert {:ok, ^state} = Volt.HMR.Socket.handle_in({"not-json", opcode: :text}, state)
    end
  end
end
