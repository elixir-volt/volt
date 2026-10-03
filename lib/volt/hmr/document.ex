defmodule Volt.HMR.Document do
  @moduledoc """
  Lets an open page ask whether its server-rendered HTML is still current.

  A change to a template or content file may affect any page, or none. Rather
  than reloading every open page, Volt's dev client revalidates the page it is
  on: it requests the page again with the entity tag of the HTML it was served
  and reloads only when the server answers with something other than
  `304 Not Modified`.

  `Volt.DevServer` does this for every successful HTML response that passes
  through it, whether it adds the dev client or the page already loads it with
  `<script type="module" src="/@volt/client.js">`. A server that sends HTML
  without going through `Volt.DevServer` takes part by:

    1. computing `etag/1` of the rendered HTML;
    2. answering `304` with an empty body when `fresh?/2` is true;
    3. otherwise sending the tag in the `etag` response header and in the
       `data-volt-etag` attribute of the client `<script>`.

  Pages without the attribute reload on every document update.
  """

  @attribute "data-volt-etag"

  @doc "The attribute of the client `<script>` that holds the page's entity tag."
  @spec attribute() :: String.t()
  def attribute, do: @attribute

  @morph_attribute "data-volt-morph"

  @doc """
  The attribute of the client `<script>` that lets the client patch the page in
  place instead of reloading it. Its value is a selector for elements that
  client code owns, or empty.
  """
  @spec morph_attribute() :: String.t()
  def morph_attribute, do: @morph_attribute

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

  @typedoc """
  A preserved element whose server-rendered attributes changed: its position
  among the elements matching the preserve selector, and its new attributes.
  """
  @type owned_change :: %{index: non_neg_integer(), attributes: %{String.t() => String.t()}}

  @doc """
  Decide how a page gets from one server render to the next.

  Both arguments are HTML the server rendered, so the comparison sees only what
  the server changed, never what scripts did to the page since.

  Returns `:reload` when patching cannot apply the change: the scripts the page
  runs or its stylesheets differ, or elements matching `preserve` were added or
  removed. Otherwise returns `{:patch, owned}`, where `owned` lists the
  preserved elements whose attributes changed. Their owner, such as a mounted
  component, is told and re-renders; the rest of the page is patched.
  """
  @spec changes(String.t(), String.t(), String.t() | nil) :: :reload | {:patch, [owned_change()]}
  def changes(previous, next, preserve) do
    previous = Floki.parse_document!(previous)
    next = Floki.parse_document!(next)

    cond do
      scripts(previous) != scripts(next) -> :reload
      stylesheets(previous) != stylesheets(next) -> :reload
      true -> owned_changes(preserved(previous, preserve), preserved(next, preserve))
    end
  end

  # Scripts the browser runs. Data blocks such as JSON are content and are patched.
  defp scripts(document) do
    for {"script", attributes, children} <- Floki.find(document, "script"),
        type = attribute(attributes, "type"),
        type in ["", "module", "text/javascript"],
        do: {type, attribute(attributes, "src"), Floki.raw_html(children)}
  end

  defp stylesheets(document) do
    links =
      for {"link", attributes, _children} <- Floki.find(document, "link[rel=stylesheet]"),
          do: attribute(attributes, "href")

    styles = for {"style", _attributes, children} <- Floki.find(document, "style"), do: children
    {links, styles}
  end

  defp preserved(_document, preserve) when preserve in [nil, ""], do: []

  defp preserved(document, preserve) do
    for {_tag, attributes, _children} <- Floki.find(document, preserve), do: Map.new(attributes)
  end

  defp owned_changes(previous, next) do
    if length(previous) == length(next) do
      owned =
        for {{before, now}, index} <- Enum.with_index(Enum.zip(previous, next)),
            before != now,
            do: %{index: index, attributes: now}

      {:patch, owned}
    else
      :reload
    end
  end

  defp attribute(attributes, name) do
    case List.keyfind(attributes, name, 0) do
      {^name, value} -> value
      nil -> ""
    end
  end
end
