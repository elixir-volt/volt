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

  describe "a page the server keeps a render of" do
    setup do
      {:ok, renders} = Agent.start_link(fn -> page("first", ~s({"n":1})) end)
      document = fn "/post" -> {:ok, Agent.get(renders, & &1)} end

      {:ok, state} =
        Volt.HMR.Socket.init(document: document, morph: [preserve: "[data-island]"])

      html = Agent.get(renders, & &1)
      opened = open_page(state, "/post", Volt.HMR.Document.etag(html))
      %{renders: renders, state: state, opened: opened}
    end

    test "hears nothing when its HTML did not change", %{opened: opened} do
      assert {:ok, ^opened} = Volt.HMR.Socket.handle_info(document_update(), opened)
    end

    test "is sent the new HTML when it can be patched", %{renders: renders, opened: opened} do
      Agent.update(renders, fn _ -> page("second", ~s({"n":1})) end)

      assert {:push, {:text, json}, state} =
               Volt.HMR.Socket.handle_info(document_update(), opened)

      assert %{"changes" => ["document"], "html" => html, "etag" => etag, "owned" => []} =
               Jason.decode!(json)["payload"]

      assert html =~ "second"

      # The pushed page keeps what marks it for the next update.
      assert html =~ ~s(data-volt-morph="[data-island]")
      assert html =~ "data-volt-etag"
      assert etag == Volt.HMR.Document.etag(Agent.get(renders, & &1))

      # The new render is what the next change is compared with.
      assert {:ok, ^state} = Volt.HMR.Socket.handle_info(document_update(), state)
    end

    test "is told which owned elements the server changed", %{renders: renders, opened: opened} do
      Agent.update(renders, fn _ -> page("first", ~s({"n":2})) end)

      assert {:push, {:text, json}, _state} =
               Volt.HMR.Socket.handle_info(document_update(), opened)

      assert [%{"index" => 0, "attributes" => %{"data-props" => ~s({"n":2})}}] =
               Jason.decode!(json)["payload"]["owned"]
    end

    test "reloads when the change cannot be patched", %{renders: renders, opened: opened} do
      Agent.update(renders, fn html -> String.replace(html, "run()", "run(2)") end)

      assert {:push, {:text, json}, _state} =
               Volt.HMR.Socket.handle_info(document_update(), opened)

      payload = Jason.decode!(json)["payload"]
      assert payload["changes"] == ["full"]
      refute Map.has_key?(payload, "html")
    end

    test "revalidates itself when it was served different HTML", %{state: state} do
      stale = open_page(state, "/post", ~s("another"))

      assert {:push, {:text, json}, _state} =
               Volt.HMR.Socket.handle_info(document_update(), stale)

      payload = Jason.decode!(json)["payload"]
      assert payload["changes"] == ["document"]
      refute Map.has_key?(payload, "html")
    end

    test "starts from the HTML it was served without rendering again" do
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      document = fn "/post" ->
        Agent.update(calls, &(&1 + 1))
        {:ok, page("first", "{}")}
      end

      served = page("first", "{}")
      etag = Volt.HMR.Document.etag(served)
      Volt.HMR.Documents.put(:default, etag, served)
      on_exit(fn -> Volt.HMR.Documents.clear_session(:default) end)

      {:ok, state} = Volt.HMR.Socket.init(document: document, morph: true)
      opened = open_page(state, "/post", etag)

      assert opened.html == served
      assert Agent.get(calls, & &1) == 0
    end

    test "is not kept track of unless pages are patched in place", %{renders: renders} do
      document = fn "/post" -> {:ok, Agent.get(renders, & &1)} end
      {:ok, state} = Volt.HMR.Socket.init(document: document)
      html = Agent.get(renders, & &1)
      opened = open_page(state, "/post", Volt.HMR.Document.etag(html))

      Agent.update(renders, fn _ -> page("second", "{}") end)

      assert {:push, {:text, json}, _state} =
               Volt.HMR.Socket.handle_info(document_update(), opened)

      refute Map.has_key?(Jason.decode!(json)["payload"], "html")
    end

    defp page(text, props) do
      """
      <html><head><title>Post</title></head><body>
        <p>#{text}</p>
        <div data-island="counter" data-props='#{props}'></div>
        <script>run()</script>
        <script type="module" src="/@volt/client.js"></script>
      </body></html>
      """
    end

    defp open_page(state, path, etag) do
      frame = Jason.encode!(%{type: "page", payload: %{path: path, etag: etag}})
      {:ok, state} = Volt.HMR.Socket.handle_in({frame, opcode: :text}, state)
      state
    end

    defp document_update,
      do: {:volt_hmr, :update, %{path: "content/post.md", changes: ["document"]}}
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
