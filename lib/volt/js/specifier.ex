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

  @doc """
  Return whether a specifier names a Node.js built-in module, including a
  subpath of one such as `timers/promises` or `node:fs/promises`.
  """
  @spec node_builtin?(String.t()) :: boolean()
  def node_builtin?("node:" <> _rest), do: true

  def node_builtin?(specifier) do
    specifier
    |> String.split("/", parts: 2)
    |> hd()
    |> NPM.Resolution.PackageResolver.node_builtin?()
  end

  @oxc_runtime "@oxc-project/runtime"

  @doc """
  Return whether a specifier names a helper from `@oxc-project/runtime`.

  OXC's transform imports these when it lowers syntax for a target, such as
  class fields below ES2022. `OXC.bundle/2` provides them itself, so they are
  never resolved from `node_modules`.
  """
  @spec oxc_runtime_helper?(String.t()) :: boolean()
  def oxc_runtime_helper?(specifier),
    do: specifier == @oxc_runtime or String.starts_with?(specifier, @oxc_runtime <> "/")

  defp split_on_query(specifier) do
    case String.split(specifier, "?", parts: 2) do
      [path, query] -> {path, query}
      [path] -> {path, ""}
    end
  end
end
