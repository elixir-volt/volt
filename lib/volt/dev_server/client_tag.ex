defmodule Volt.DevServer.ClientTag do
  @moduledoc false
  # Loads the HMR client as its own script in HTML pages, as Vite does. Modules
  # also import the client, but a module that fails to compile stops its whole
  # graph from running, and the client must still show the error overlay.

  alias Plug.Conn

  alias Volt.HMR.Document

  @client "/@volt/client.js"

  @spec register(Conn.t()) :: Conn.t()
  def register(conn), do: Conn.register_before_send(conn, &inject/1)

  defp inject(%Conn{resp_body: body} = conn) when not is_nil(body) do
    if html?(conn) do
      html = IO.iodata_to_binary(body)

      if String.contains?(html, @client),
        do: conn,
        else: inject_client(conn, html)
    else
      conn
    end
  end

  defp inject(conn), do: conn

  # Successful pages carry an entity tag so the client can revalidate them
  # instead of reloading; see `Volt.HMR.Document`.
  defp inject_client(%Conn{status: 200} = conn, html) do
    etag = Document.etag(html)

    if Document.fresh?(conn, etag) do
      %{conn | status: 304, resp_body: ""}
    else
      conn = Conn.put_resp_header(conn, "etag", etag)
      %{conn | resp_body: insert(html, tag(etag))}
    end
  end

  defp inject_client(conn, html), do: %{conn | resp_body: insert(html, tag(nil))}

  defp tag(nil), do: ~s(<script type="module" src="#{@client}"></script>)

  defp tag(etag) do
    value = Plug.HTML.html_escape(etag)
    ~s(<script type="module" src="#{@client}" #{Document.attribute()}="#{value}"></script>)
  end

  defp html?(conn) do
    conn
    |> Conn.get_resp_header("content-type")
    |> Enum.any?(&String.starts_with?(&1, "text/html"))
  end

  defp insert(html, tag) do
    case :binary.match(html, "</head>") do
      {position, _length} ->
        binary_part(html, 0, position) <>
          tag <> binary_part(html, position, byte_size(html) - position)

      :nomatch ->
        html
    end
  end
end
