defmodule Volt.HMR.Socket do
  @moduledoc """
  WebSocket handler for HMR updates.

  Receives file change events from `Volt.Watcher` via the HMR registry
  and pushes JSON messages to connected browsers.
  """
  @behaviour WebSock
  require Logger

  @impl true
  def init(_args) do
    Registry.register(Volt.HMR.Registry, :clients, nil)
    {:ok, %{}}
  end

  # Heartbeat: the browser client sends a `{"type":"ping"}` JSON message
  # every few seconds to keep Bandit's websocket `read_timeout` from closing
  # an otherwise idle connection. We reply with `{"type":"pong"}` so the
  # client can also detect a dead link and reconnect. Both messages flow
  # through the `Volt.HMR.Message` JSONCodec.
  @impl true
  def handle_in({text, opcode: :text}, state) do
    case Volt.HMR.Message.decode(text) do
      {:ok, %Volt.HMR.Message{type: :ping}} ->
        push(%Volt.HMR.Message{type: :pong}, state)

      {:ok, %Volt.HMR.Message{type: type} = message} ->
        Logger.debug("[Volt.HMR] Received: #{inspect(type)} #{inspect(message.payload)}")
        {:ok, state}

      {:error, reason} ->
        Logger.debug("[Volt.HMR] Ignoring malformed frame: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl true
  def handle_info({:volt_hmr, type, payload}, state) do
    push(%Volt.HMR.Message{type: type, payload: payload}, state)
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  defp push(%Volt.HMR.Message{} = message, state) do
    case encode(message) do
      {:ok, frame} -> {:push, frame, state}
      :error -> {:ok, state}
    end
  end

  defp encode(%Volt.HMR.Message{} = message) do
    {:ok, {:text, message |> Volt.HMR.Message.dump() |> Jason.encode!()}}
  rescue
    error ->
      Logger.warning(
        "[Volt.HMR] Failed to encode #{inspect(message.type)} payload: #{inspect(error)}"
      )

      :error
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
