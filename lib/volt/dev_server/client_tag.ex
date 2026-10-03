defmodule Volt.DevServer.ClientTag do
  @moduledoc false
  # Loads the HMR client as its own script in HTML pages, as Vite does. Modules
  # also import the client, but a module that fails to compile stops its whole
  # graph from running, and the client must still show the error overlay.

  alias Plug.Conn

  alias Volt.HMR.Document

  @client "/@volt/client.js"
  @src ~s(src="#{@client}")

  @doc """
  Add the dev client to the HTML this connection sends.

  `morph` is the server's `:morph` setting: `false`, `true`, or
  `[preserve: selector]`.
  """
  @spec register(Conn.t(), boolean() | keyword()) :: Conn.t()
  def register(conn, morph \\ false), do: Conn.register_before_send(conn, &inject(&1, morph))

  defp inject(%Conn{resp_body: body} = conn, morph) when not is_nil(body) do
    if html?(conn), do: inject_client(conn, IO.iodata_to_binary(body), morph), else: conn
  end

  defp inject(conn, _morph), do: conn

  # Successful pages carry an entity tag so the client can revalidate them
  # instead of reloading; see `Volt.HMR.Document`.
  defp inject_client(%Conn{status: 200} = conn, html, morph) do
    etag = Document.etag(html)

    if Document.fresh?(conn, etag) do
      %{conn | status: 304, resp_body: ""}
    else
      attributes = attribute(Document.attribute(), etag) <> morph_attribute(morph)
      conn = Conn.put_resp_header(conn, "etag", etag)
      %{conn | resp_body: put_client(html, attributes)}
    end
  end

  defp inject_client(conn, html, _morph), do: %{conn | resp_body: put_client(html, "")}

  # A page may already load the client, as pages rendered by a site generator
  # do. Its tag gets the attributes; otherwise the client is added to the head.
  defp put_client(html, attributes) do
    if String.contains?(html, @client) do
      String.replace(html, @src, @src <> attributes, global: false)
    else
      insert(html, ~s(<script type="module" #{@src}#{attributes}></script>))
    end
  end

  defp morph_attribute(false), do: ""
  defp morph_attribute(true), do: attribute(Document.morph_attribute(), "")

  defp morph_attribute(opts) when is_list(opts),
    do: attribute(Document.morph_attribute(), Keyword.get(opts, :preserve, ""))

  defp attribute(name, value),
    do: ~s( #{name}="#{value |> Plug.HTML.html_escape() |> IO.iodata_to_binary()}")

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
