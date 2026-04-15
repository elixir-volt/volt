defmodule Volt.JS.Extensions do
  @moduledoc false

  @js ~w(.ts .tsx .js .jsx .mts .mjs)
  @cjs ~w(.cjs .cts)
  @vue ~w(.vue)
  @css ~w(.css)
  @json ~w(.json)
  @template ~w(.ex .heex .eex .leex .sface)

  def js, do: @js
  def compilable, do: @vue ++ @js ++ @css ++ @json
  def resolvable, do: ["" | @js ++ @cjs ++ @vue ++ @json]
  def resolvable_index, do: ~w(/index.ts /index.tsx /index.js /index.jsx)
  def watchable_js, do: @vue ++ @js ++ @css
  def template, do: @template
end
