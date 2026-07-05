defmodule Volt.Test.Sigils do
  @moduledoc """
  Convenience sigils for JavaScript, TypeScript, JSX, TSX, CSS, and HTML test fixtures.

  These sigils are intentionally small: they return normalized source strings for
  ExUnit tests and examples. Use the optional `v` modifier to validate JS/TS-like
  snippets with OXC at runtime.

      import Volt.Test.Sigils

      source = ~TS"const answer: number = 42"

      assert source =~ "answer"

      # Validate parser compatibility when the snippet is expected to be valid.
      source = ~TS"export const value: string = \"ok\""v

  The multi-letter sigils are intentionally uppercase, which means Elixir does
  not process escapes or interpolation before the source reaches Volt. This is
  usually what JS/TS fixtures want.
  """

  @js_like_sigils %{
    JS: "snippet.js",
    TS: "snippet.ts",
    JSX: "snippet.jsx",
    TSX: "snippet.tsx"
  }

  @doc "Returns normalized JavaScript source. Use `v` to validate with OXC."
  def sigil_JS(source, modifiers), do: js_like(:JS, source, modifiers)

  @doc "Returns normalized TypeScript source. Use `v` to validate with OXC."
  def sigil_TS(source, modifiers), do: js_like(:TS, source, modifiers)

  @doc "Returns normalized JSX source. Use `v` to validate with OXC."
  def sigil_JSX(source, modifiers), do: js_like(:JSX, source, modifiers)

  @doc "Returns normalized TSX source. Use `v` to validate with OXC."
  def sigil_TSX(source, modifiers), do: js_like(:TSX, source, modifiers)

  @doc "Returns normalized CSS source."
  def sigil_CSS(source, _modifiers), do: normalize(source)

  @doc "Returns normalized HTML source."
  def sigil_HTML(source, _modifiers), do: normalize(source)

  defp js_like(kind, source, modifiers) do
    source = normalize(source)

    if ?v in modifiers do
      validate!(source, Map.fetch!(@js_like_sigils, kind))
    end

    source
  end

  defp normalize(source) do
    source
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
  end

  defp validate!(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, _ast} -> :ok
      {:error, errors} -> raise ArgumentError, "invalid #{filename} source: #{inspect(errors)}"
    end
  end
end
