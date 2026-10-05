defmodule Volt.HMR.Documents do
  @moduledoc false
  # The HTML recently served for pages, per session and entity tag, so the
  # websocket process of a page that connects can start from the HTML the page
  # was served without rendering it again.

  @table :volt_hmr_documents

  # Pages that never connect, such as requests from other tools, leave their
  # HTML behind. A session keeps at most this many before starting over.
  @limit 64

  def create_table, do: Volt.ETS.create_named_set(@table)

  def put(session, etag, html) do
    if count(session) >= @limit, do: clear_session(session)
    Volt.ETS.put(@table, {{session, etag}, html})
  end

  @spec fetch(term(), String.t()) :: {:ok, String.t()} | :error
  def fetch(session, etag) do
    case :ets.lookup(@table, {session, etag}) do
      [{_key, html}] -> {:ok, html}
      [] -> :error
    end
  end

  def clear_session(session), do: Volt.ETS.clear_session(@table, session)

  defp count(session), do: :ets.select_count(@table, [{{{session, :_}, :_}, [], [true]}])
end
