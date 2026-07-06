defmodule Volt.JS.Specifier do
  @moduledoc "Helpers for JavaScript module specifier strings."

  @doc """
  Splits a JavaScript module specifier into its path-like part and query string.

  Unlike URL parsing, this preserves package import specifiers such as
  `#client/constants`, where the leading `#` is part of the JavaScript module
  specifier rather than a URL fragment marker.
  """
  @spec split_query(String.t()) :: {String.t(), String.t()}
  def split_query("#" <> rest) do
    {path, query} = split_on_query(rest)
    {"#" <> path, query}
  end

  def split_query(specifier), do: Volt.URL.split_query(specifier)

  defp split_on_query(specifier) do
    case String.split(specifier, "?", parts: 2) do
      [path, query] -> {path, query}
      [path] -> {path, ""}
    end
  end
end
