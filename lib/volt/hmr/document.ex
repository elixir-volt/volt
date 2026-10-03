defmodule Volt.HMR.Document do
  @moduledoc """
  Lets an open page ask whether its server-rendered HTML is still current.

  A change to a template or content file may affect any page, or none. Rather
  than reloading every open page, Volt's dev client revalidates the page it is
  on: it requests the page again with the entity tag of the HTML it was served
  and reloads only when the server answers with something other than
  `304 Not Modified`.

  `Volt.DevServer` does this for the HTML responses it adds the dev client to.
  A server that adds the client itself takes part by:

    1. computing `etag/1` of the rendered HTML, before adding the client;
    2. answering `304` with an empty body when `fresh?/2` is true;
    3. otherwise sending the tag in the `etag` response header and in the
       `#{"data-volt-etag"}` attribute of the client `<script>`.

  Pages without the attribute reload on every document update.
  """

  @attribute "data-volt-etag"

  @doc "The attribute of the client `<script>` that holds the page's entity tag."
  @spec attribute() :: String.t()
  def attribute, do: @attribute

  @doc "Compute the entity tag of rendered HTML."
  @spec etag(iodata()) :: String.t()
  def etag(html) do
    digest =
      :crypto.hash(:sha256, html) |> Base.url_encode64(padding: false) |> binary_part(0, 22)

    ~s("#{digest}")
  end

  @doc "Return whether the request already holds the HTML that `etag` identifies."
  @spec fresh?(Plug.Conn.t(), String.t()) :: boolean()
  def fresh?(conn, etag), do: etag in Plug.Conn.get_req_header(conn, "if-none-match")
end
