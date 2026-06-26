defmodule Volt.Integration.HMRWebSocketTest do
  use ExUnit.Case, async: false

  alias Mint.WebSocket

  @moduletag :integration

  # Short server-side websocket idle timeout so we can exercise the
  # heartbeat/timeout behavior without waiting 60 seconds.
  @hmr_timeout 2_000

  @fixture_dir Path.expand("../fixtures/integration_hmr_ws", __DIR__)

  defp port do
    # Unique port per test run to avoid TIME_WAIT / :eaddrinuse races between
    # sequential integration tests.
    50_000 + rem(System.unique_integer([:positive, :monotonic]), 10_000)
  end

  defmodule TestPlug do
    @moduledoc false
    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, opts) do
      case Volt.DevServer.call(conn, opts[:dev_server]) do
        %{halted: true} = conn -> conn
        conn -> Elixir.Plug.Conn.send_resp(conn, 404, "not found")
      end
    end
  end

  setup do
    port = port()
    File.rm_rf!(@fixture_dir)
    File.mkdir_p!(@fixture_dir)
    Volt.Cache.clear()

    File.write!(Path.join(@fixture_dir, "app.ts"), "export const v = 1\n")

    dev_server_opts =
      Volt.DevServer.init(root: @fixture_dir, prefix: "/assets", hmr_timeout: @hmr_timeout)

    plug_opts = %{root: @fixture_dir, dev_server: dev_server_opts}

    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__.TestPlug, plug_opts},
        port: port,
        ip: :loopback,
        startup_log: false
      )

    on_exit(fn ->
      Process.exit(server, :normal)
      File.rm_rf!(@fixture_dir)
    end)

    {:ok, port: port}
  end

  describe "HMR websocket idle timeout" do
    test "an idle connection is closed by the server after hmr_timeout", %{port: port} do
      {:ok, conn, ws, _ref} = connect!(port)

      # Send nothing. The server should close the socket once its read_timeout
      # fires (well within 2x the configured timeout).
      assert {{:close, _, _}, _ws} = recv_frame(conn, ws, @hmr_timeout * 2)
    end

    test "a heartbeat ping keeps the connection alive past hmr_timeout", %{port: port} do
      {:ok, conn, ws, ref} = connect!(port)

      # Send a ping well inside the timeout window and expect a pong.
      {:ok, ws} = send_text(conn, ref, ws, ~s({"type":"ping"}))
      assert {{:text, pong}, _ws} = recv_frame(conn, ws, 1_000)
      assert Jason.decode!(pong)["type"] == "pong"

      # Keep heartbeating past the idle timeout. If the heartbeat did not
      # reset Bandit's read_timeout, the server would have closed us by now.
      deadline = System.monotonic_time(:millisecond) + @hmr_timeout * 2

      assert stay_alive?(conn, ref, ws, deadline)
    end
  end

  # ── Mint WebSocket client helpers ──────────────────────────────

  defp connect!(port) do
    {:ok, conn} = Mint.HTTP.connect(:http, "localhost", port, mode: :passive)
    {:ok, conn, ref} = WebSocket.upgrade(:ws, conn, "/@volt/ws", [])

    # Drain the upgrade response.
    {:ok, conn, responses} = WebSocket.recv(conn, 0, 1_000)
    {:status, ^ref, 101} = Enum.find(responses, &match?({:status, _, _}, &1))

    headers =
      Enum.find_value(responses, [], fn
        {:headers, ^ref, h} when is_list(h) -> h
        _ -> nil
      end)

    {:ok, conn, ws} = WebSocket.new(conn, ref, 101, headers, mode: :passive)

    {:ok, conn, ws, ref}
  end

  defp send_text(conn, ref, ws, text) do
    {:ok, ws, data} = WebSocket.encode(ws, {:text, text})

    case Mint.WebSocket.stream_request_body(conn, ref, data) do
      {:ok, _conn} -> {:ok, ws}
      {:error, _conn, reason} -> {:error, reason}
    end
  end

  defp recv_frame(conn, ws, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    recv_frame_loop(conn, ws, deadline)
  end

  defp recv_frame_loop(conn, ws, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    case WebSocket.recv(conn, 0, remaining) do
      {:ok, conn, responses} ->
        case extract_data(responses) do
          {:data, data} ->
            case WebSocket.decode(ws, data) do
              {:ok, ws, [frame | _]} -> {frame, ws}
              {:ok, _ws, []} -> recv_frame_loop(conn, ws, deadline)
              {:error, _ws, reason} -> {{:error, reason}, ws}
            end

          :none ->
            recv_frame_loop(conn, ws, deadline)
        end

      {:error, _conn, %Mint.TransportError{reason: :timeout}, _} ->
        {:timeout, ws}

      {:error, _conn, reason, _} ->
        {{:error, reason}, ws}
    end
  end

  defp extract_data(responses) do
    Enum.find_value(responses, :none, fn
      {:data, _ref, data} -> {:data, data}
      _ -> nil
    end)
  end

  defp stay_alive?(conn, ref, ws, deadline) do
    interval = div(@hmr_timeout, 2)
    stay_alive_loop(conn, ref, ws, deadline, interval)
  end

  defp stay_alive_loop(conn, ref, ws, deadline, interval) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      true
    else
      {:ok, ws} = send_text(conn, ref, ws, ~s({"type":"ping"}))

      # Drain any pong (or a close if the server gave up, which would fail us).
      case recv_frame(conn, ws, interval + 500) do
        {{:text, pong}, ws} when is_binary(pong) ->
          if Jason.decode!(pong)["type"] == "pong" do
            Process.sleep(max(interval - 200, 0))
            stay_alive_loop(conn, ref, ws, deadline, interval)
          else
            {:unexpected, pong}
          end

        {{:close, _, _}, _ws} ->
          false

        {:timeout, ws} ->
          # No pong this round but socket still open — keep going until deadline.
          stay_alive_loop(conn, ref, ws, deadline, interval)

        {other, _ws} ->
          other
      end
    end
  end
end
