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

  @impl true
  def handle_in({text, opcode: :text}, state) do
    Logger.debug("[Volt.HMR] Received: #{text}")
    {:ok, state}
  end

  @impl true
  def handle_info({:volt_hmr, type, payload}, state) do
    msg = Jason.encode!(%{type: type, payload: payload})
    {:push, {:text, msg}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
