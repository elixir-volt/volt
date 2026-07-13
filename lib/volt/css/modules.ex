defmodule Volt.CSS.Modules do
  @moduledoc """
  CSS Modules support for `.module.css`, `.module.scss`, and `.module.sass` files.

  Uses LightningCSS (via Vize) for proper CSS parsing and class name scoping.
  LightningCSS handles selectors, keyframes, custom identifiers, `composes`,
  nested rules, and all other CSS constructs correctly.

  ## Example

  Given `button.module.css`:

      .primary { color: blue }
      .large { font-size: 2em }

  Produces scoped CSS and a JS module exporting the name mapping:

      export default {"primary":"ewq3O_primary","large":"ewq3O_large"}
  """

  @doc "Check if a file path is a CSS Module."
  @spec css_module?(String.t()) :: boolean()
  def css_module?(path),
    do: String.ends_with?(path, [".module.css", ".module.scss", ".module.sass"])

  @doc """
  Compile a CSS Module file.

  Returns `{:ok, js_code, scoped_css}` where `js_code` exports the
  class name mapping and `scoped_css` has LightningCSS-rewritten names.
  """
  @spec compile(String.t(), String.t(), keyword()) :: {:ok, String.t(), String.t()}
  def compile(source, filename, opts \\ []) do
    minify = Keyword.get(opts, :minify, false)

    {:ok, result} =
      Vize.CSS.compile(source, minify: minify, css_modules: true, filename: filename)

    js =
      OXC.parse!("var _exports = $exports;\nexport default _exports;", "css-module.js")
      |> OXC.bind(exports: {:literal, result.exports})
      |> OXC.codegen!()

    {:ok, js, result.code}
  end
end
