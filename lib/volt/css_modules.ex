defmodule Volt.CSSModules do
  @moduledoc """
  CSS Modules support for `.module.css` files.

  Uses LightningCSS (via Vize) for proper CSS parsing and class name scoping.
  LightningCSS handles all the complexity: selectors, keyframes, custom
  identifiers, `composes`, and nested rules.

  ## Example

  Given `button.module.css`:

      .primary { color: blue }
      .large { font-size: 2em }

  Produces scoped CSS and a JS module exporting the name mapping:

      export default {"primary":"ewq3O_primary","large":"ewq3O_large"}
  """

  @doc "Check if a file path is a CSS Module."
  @spec css_module?(String.t()) :: boolean()
  def css_module?(path), do: String.ends_with?(path, ".module.css")

  @doc """
  Compile a CSS Module file.

  Returns `{:ok, js_code, scoped_css}` where `js_code` exports the
  class name mapping and `scoped_css` has LightningCSS-rewritten names.
  """
  @spec compile(String.t(), String.t(), keyword()) :: {:ok, String.t(), String.t()}
  def compile(source, filename, opts \\ []) do
    minify = Keyword.get(opts, :minify, false)

    case Vize.compile_css(source, minify: minify, css_modules: true, filename: filename) do
      {:ok, %{exports: exports} = result} when is_map(exports) and map_size(exports) > 0 ->
        js = "export default #{Jason.encode!(exports)};\n"
        {:ok, js, result.code}

      _no_css_modules_support ->
        # Vize version without css_modules support — fall back to regex scoping,
        # then run through LightningCSS for minification/autoprefixing.
        {js, scoped_css} = regex_fallback(source, filename)

        scoped_css =
          case Vize.compile_css(scoped_css, minify: minify) do
            {:ok, %{code: processed}} -> processed
            _ -> scoped_css
          end

        {:ok, js, scoped_css}
    end
  end

  # Temporary fallback until Vize ships with css_modules support.
  # Uses regex — only handles simple class selectors.
  defp regex_fallback(source, filename) do
    hash = :crypto.hash(:md5, filename) |> Base.encode16(case: :lower) |> binary_part(0, 5)

    class_names =
      ~r/\.([a-zA-Z_][\w-]*)/
      |> Regex.scan(source)
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.uniq()

    mapping = Map.new(class_names, fn name -> {name, "_#{name}_#{hash}"} end)

    scoped_css =
      Regex.replace(~r/\.([a-zA-Z_][\w-]*)/, source, fn _full, name ->
        case Map.fetch(mapping, name) do
          {:ok, scoped} -> ".#{scoped}"
          :error -> ".#{name}"
        end
      end)

    js = "export default #{Jason.encode!(mapping)};\n"
    {js, scoped_css}
  end
end
