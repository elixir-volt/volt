defmodule Volt.CSSModules do
  @moduledoc """
  CSS Modules support for `.module.css` files.

  Transforms class names to scoped identifiers and generates
  a JavaScript module exporting the name mapping.

  ## Example

  Given `button.module.css`:

      .primary { color: blue }
      .large { font-size: 2em }

  Produces:

      /* CSS with scoped classes */
      ._primary_x7k2a { color: blue }
      ._large_x7k2a { font-size: 2em }

      // JS module
      export default {"primary":"_primary_x7k2a","large":"_large_x7k2a"}
  """

  @class_re ~r/\.([a-zA-Z_][\w-]*)/

  @doc """
  Compile a CSS Module file.

  Returns `{:ok, js_code, scoped_css}` where `js_code` is the export
  mapping and `scoped_css` has rewritten class names.
  """
  @spec compile(String.t(), String.t()) :: {:ok, String.t(), String.t()}
  def compile(source, filename) do
    hash = scope_hash(filename)
    class_names = extract_class_names(source)

    mapping =
      Map.new(class_names, fn name ->
        {name, "_#{name}_#{hash}"}
      end)

    scoped_css = rewrite_classes(source, mapping)

    js =
      "export default #{Jason.encode!(mapping)};\n"

    {:ok, js, scoped_css}
  end

  @doc "Check if a file path is a CSS Module."
  @spec css_module?(String.t()) :: boolean()
  def css_module?(path), do: String.ends_with?(path, ".module.css")

  defp extract_class_names(source) do
    @class_re
    |> Regex.scan(source)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  defp rewrite_classes(source, mapping) do
    Regex.replace(@class_re, source, fn _full, name ->
      case Map.fetch(mapping, name) do
        {:ok, scoped} -> ".#{scoped}"
        :error -> ".#{name}"
      end
    end)
  end

  defp scope_hash(filename) do
    :crypto.hash(:md5, filename)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 5)
  end
end
