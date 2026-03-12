defmodule Volt.Pipeline do
  @moduledoc """
  Compile source files to browser-ready JavaScript and CSS.

  Dispatches to OXC for JS/TS/JSX/TSX and Vize for Vue SFCs and CSS.
  Returns compiled output with optional sourcemaps.
  """

  @type compiled :: %{
          code: String.t(),
          sourcemap: String.t() | nil,
          css: String.t() | nil,
          hashes:
            %{template: String.t() | nil, style: String.t() | nil, script: String.t() | nil} | nil
        }

  @vue_ext ".vue"
  @js_exts ~w(.ts .tsx .js .jsx .mts .mjs)
  @css_exts ~w(.css)

  @doc """
  Compile a source file to browser-ready output.

  ## Options

    * `:target` — downlevel target (e.g. `"es2020"`)
    * `:import_source` — JSX import source (e.g. `"vue"`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:minify` — minify output (default: `false`)
    * `:vapor` — use Vue Vapor mode (default: `false`)
  """
  @spec compile(String.t(), String.t(), keyword()) :: {:ok, compiled()} | {:error, term()}
  def compile(path, source, opts \\ []) do
    ext = Path.extname(path)

    cond do
      ext == @vue_ext -> compile_vue(path, source, opts)
      ext in @js_exts -> compile_js(path, source, opts)
      ext in @css_exts -> compile_css(source, opts)
      true -> {:error, {:unsupported, ext}}
    end
  end

  defp compile_vue(path, source, opts) do
    vapor = Keyword.get(opts, :vapor, false)

    case Vize.compile_sfc(source, filename: Path.basename(path), vapor: vapor) do
      {:ok, result} ->
        {:ok,
         %{
           code: result.code,
           sourcemap: nil,
           css: result.css,
           hashes: %{
             template: result.template_hash,
             style: result.style_hash,
             script: result.script_hash
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compile_js(path, source, opts) do
    sourcemap = Keyword.get(opts, :sourcemap, true)
    target = Keyword.get(opts, :target, "")
    import_source = Keyword.get(opts, :import_source, "")

    transform_opts = [
      sourcemap: sourcemap,
      target: target,
      import_source: import_source
    ]

    case OXC.transform(source, Path.basename(path), transform_opts) do
      {:ok, result} when is_map(result) ->
        {:ok, %{code: result.code, sourcemap: result.sourcemap, css: nil, hashes: nil}}

      {:ok, code} when is_binary(code) ->
        {:ok, %{code: code, sourcemap: nil, css: nil, hashes: nil}}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp compile_css(source, opts) do
    minify = Keyword.get(opts, :minify, false)

    case Vize.compile_css(source, minify: minify) do
      {:ok, result} ->
        {:ok, %{code: result.code, sourcemap: nil, css: nil, hashes: nil}}
    end
  end
end
