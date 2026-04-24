defmodule Volt.JS.Extensions do
  @moduledoc false

  @js ~w(.ts .tsx .js .jsx .mts .mjs)
  @cjs ~w(.cjs .cts)
  @css ~w(.css)
  @json ~w(.json)
  @template ~w(.ex .heex .eex .leex .sface)

  def js, do: @js
  def bundleable, do: @js ++ @cjs
  def compilable(plugins \\ []), do: plugin_exts(plugins, :compile) ++ @js ++ @css ++ @json
  def scannable(plugins \\ []), do: plugin_exts(plugins, :scan) ++ @js
  def resolvable(plugins \\ []), do: ["" | @js ++ @cjs ++ plugin_exts(plugins, :resolve) ++ @json]
  def resolvable_index, do: ~w(/index.ts /index.tsx /index.js /index.jsx)
  def watchable_js(plugins \\ []), do: plugin_exts(plugins, :watch) ++ @js ++ @css
  def template, do: @template
  def css, do: @css ++ ~w(.scss .sass .less .styl)

  def apply_loader(filename, loaders) do
    ext = Path.extname(filename)

    case Map.get(loaders, ext) do
      "jsx" -> Path.rootname(filename) <> ".jsx"
      "tsx" -> Path.rootname(filename) <> ".tsx"
      _ -> filename
    end
  end

  defp plugin_exts(plugins, kind) do
    Volt.PluginRunner.extensions(plugins, kind)
  end
end
