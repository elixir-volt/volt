defmodule Volt.DevServer.ClientTag do
  @moduledoc false
  # Loads the HMR client as its own script in HTML pages, as Vite does. Modules
  # also import the client, but a module that fails to compile stops its whole
  # graph from running, and the client must still show the error overlay.

  alias Plug.Conn

  @client "/@volt/client.js"
  @tag ~s(<script type="module" src="#{@client}"></script>)

  @spec register(Conn.t()) :: Conn.t()
  def register(conn), do: Conn.register_before_send(conn, &inject/1)

  defp inject(%Conn{resp_body: body} = conn) when not is_nil(body) do
    if html?(conn) do
      html = IO.iodata_to_binary(body)

      if String.contains?(html, @client),
        do: conn,
        else: %{conn | resp_body: insert(html)}
    else
      conn
    end
  end

  defp inject(conn), do: conn

  defp html?(conn) do
    conn
    |> Conn.get_resp_header("content-type")
    |> Enum.any?(&String.starts_with?(&1, "text/html"))
  end

  defp insert(html) do
    case :binary.match(html, "</head>") do
      {position, _length} ->
        binary_part(html, 0, position) <>
          @tag <> binary_part(html, position, byte_size(html) - position)

      :nomatch ->
        html
    end
  end
end
