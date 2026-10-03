defmodule Volt.HMR.Socket do
  @moduledoc """
  WebSocket handler for HMR updates.

  Receives file change events from `Volt.Watcher` via the HMR registry
  and pushes JSON messages to connected browsers.
  """
  @behaviour WebSock
  require Logger

  alias Volt.HMR.Document

  # One socket process lives as long as one open page. When the server can
  # render documents and pages are patched in place, the process keeps the HTML
  # the server last rendered for its page. On a document update it renders the
  # page again and compares the two renders, so each page hears only what
  # applies to it: nothing, a reload, or a patch.
  defstruct session: :default, document: nil, morph: false, path: nil, html: nil

  @impl true
  def init(nil), do: init([])

  def init(args) do
    session = Keyword.get(args, :session, :default)
    Registry.register(Volt.HMR.Registry, Volt.HMR.Channel.key(session), nil)

    morph = Keyword.get(args, :morph, false)

    state = %__MODULE__{
      session: session,
      document: document(Keyword.get(args, :document), morph),
      morph: morph
    }

    case Volt.HMR.Errors.list(session) do
      [] -> {:ok, state}
      errors -> push(%Volt.HMR.Message{type: :error, payload: %{errors: errors}}, state)
    end
  end

  # Without patching, a changed page reloads and fetches its own HTML.
  defp document(_document, false), do: nil
  defp document(document, _morph), do: document

  defp preserve(morph) when is_list(morph), do: Keyword.get(morph, :preserve)
  defp preserve(_morph), do: nil

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

      {:ok, %Volt.HMR.Message{type: :page, payload: payload}} ->
        {:ok, open_page(state, payload)}

      {:ok, %Volt.HMR.Message{type: type} = message} ->
        Logger.debug("[Volt.HMR] Received: #{inspect(type)} #{inspect(message.payload)}")
        {:ok, state}

      {:error, reason} ->
        Logger.debug("[Volt.HMR] Ignoring malformed frame: #{inspect(reason)}")
        {:ok, state}
    end
  end

  # The page says where it is and which HTML it was served. That HTML was kept
  # when it was sent. If it is gone, the page is rendered again, and the render
  # is used only if it is the HTML the page has; otherwise the page falls back
  # to revalidating itself.
  defp open_page(%__MODULE__{document: document} = state, %{"path" => path, "etag" => etag})
       when not is_nil(document) and is_binary(path) and is_binary(etag) do
    %{state | path: path, html: served_html(state, path, etag)}
  end

  defp open_page(state, _payload), do: state

  @impl true
  def handle_info(
        {:volt_hmr, :update, %{changes: ["document"]} = payload},
        %__MODULE__{html: html} = state
      )
      when is_binary(html) do
    case render(state.document, state.path) do
      {:ok, ^html} ->
        {:ok, state}

      {:ok, next} ->
        update_document(Document.changes(html, next, preserve(state.morph)), next, payload, state)

      _error ->
        # The page revalidates itself and shows what the server answers.
        push(%Volt.HMR.Message{type: :update, payload: payload}, %{state | html: nil})
    end
  end

  def handle_info({:volt_hmr, type, payload}, state) do
    push(%Volt.HMR.Message{type: type, payload: payload}, state)
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  defp update_document(:reload, _next, payload, state) do
    payload = %{payload | changes: ["full"]}
    push(%Volt.HMR.Message{type: :update, payload: payload}, %{state | html: nil})
  end

  defp update_document({:patch, patch}, next, payload, state) do
    etag = Document.etag(next)

    # The page gets the HTML a request for it would be answered with.
    tagged = Volt.DevServer.ClientTag.tag(next, etag, state.morph)
    payload = payload |> Map.merge(patch) |> Map.merge(%{html: tagged, etag: etag})
    push(%Volt.HMR.Message{type: :update, payload: payload}, %{state | html: next})
  end

  defp served_html(state, path, etag) do
    with :error <- Volt.HMR.Documents.fetch(state.session, etag),
         {:ok, html} <- render(state.document, path),
         ^etag <- Document.etag(html) do
      html
    else
      {:ok, html} -> html
      _other -> nil
    end
  end

  defp render({module, function, args}, path), do: apply(module, function, [path | args])
  defp render(document, path) when is_function(document, 1), do: document.(path)

  defp push(%Volt.HMR.Message{} = message, state) do
    case encode(message) do
      {:ok, frame} -> {:push, frame, state}
      :error -> {:ok, state}
    end
  end

  defp encode(%Volt.HMR.Message{} = message) do
    case message |> Volt.HMR.Message.dump() |> Jason.encode() do
      {:ok, json} ->
        {:ok, {:text, json}}

      {:error, error} ->
        Logger.warning(
          "[Volt.HMR] Failed to encode #{inspect(message.type)} payload: #{inspect(error)}"
        )

        :error
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
