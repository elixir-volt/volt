defmodule Volt.HMRTest do
  use ExUnit.Case, async: false

  setup do
    Registry.register(Volt.HMR.Registry, :clients, nil)
    :ok
  end

  test "scoped broadcasts do not reach other sessions or default subscribers" do
    parent = self()

    clients =
      for session <- [:site_a, :site_b] do
        pid =
          spawn_link(fn ->
            {:ok, _} = Volt.HMR.Socket.init(session: session)
            send(parent, {:ready, self()})

            receive do
              :inspect -> send(parent, {:messages, self(), Process.info(self(), :messages)})
            end
          end)

        assert_receive {:ready, ^pid}
        {session, pid}
      end

    Volt.HMR.style_update("/assets/app.css", session: :site_a)
    for {_session, pid} <- clients, do: send(pid, :inspect)

    for {session, pid} <- clients do
      assert_receive {:messages, ^pid, {:messages, messages}}

      expected =
        if session == :site_a,
          do: [{:volt_hmr, :update, %{path: "/assets/app.css", changes: ["style"]}}],
          else: []

      assert messages == expected
    end

    refute_received {:volt_hmr, _, _}
  end

  test "broadcast sends HMR messages to connected clients" do
    assert :ok = Volt.HMR.broadcast(:update, %{path: "index.html", changes: ["full"]})

    assert_receive {:volt_hmr, :update, %{path: "index.html", changes: ["full"]}}
  end

  test "update normalizes change atoms" do
    assert :ok = Volt.HMR.update("index.html", [:hmr], boundary: "/assets/app.ts", timestamp: 123)

    assert_receive {:volt_hmr, :update,
                    %{
                      path: "index.html",
                      changes: ["hmr"],
                      boundary: "/assets/app.ts",
                      timestamp: 123
                    }}
  end

  test "full_reload and style_update broadcast update payloads" do
    assert :ok = Volt.HMR.full_reload("index.html")
    assert_receive {:volt_hmr, :update, %{path: "index.html", changes: ["full"]}}

    assert :ok = Volt.HMR.style_update("app.css")
    assert_receive {:volt_hmr, :update, %{path: "app.css", changes: ["style"]}}
  end

  test "error broadcasts error payload" do
    assert :ok = Volt.HMR.error("index.html", "boom")
    assert_receive {:volt_hmr, :error, %{path: "index.html", reason: "boom"}}
  end

  test "invalidate_file evicts dev compilation state" do
    path = Path.join(System.tmp_dir!(), "volt-hmr-test/app.ts")
    Volt.Cache.put(path, 1, %{code: "old", sourcemap: nil, content_type: "text/javascript"})
    Volt.HMR.ModuleGraph.update_module("/assets/app.ts", "/assets/app.ts", path, [])

    assert :ok = Volt.HMR.invalidate_file(path)

    assert Volt.Cache.get(path, 1) == nil
    [%{last_invalidated_at: timestamp}] = Volt.HMR.ModuleGraph.get_by_file(path)
    assert is_integer(timestamp)
  end
end
