defmodule Volt.Pipeline do
  @moduledoc """
  Compile source files to browser-ready JavaScript and CSS.

  Dispatches to OXC for JS/TS/JSX/TSX and Vize for Vue SFCs and CSS.
  Returns compiled output with optional sourcemaps.
  """

  @type rewrite_fn :: (String.t() -> {:rewrite, String.t()} | :keep)

  @type compiled :: %{
          code: String.t(),
          sourcemap: String.t() | nil,
          css: String.t() | nil,
          hashes:
            %{template: String.t() | nil, style: String.t() | nil, script: String.t() | nil} | nil
        }

  @vue_ext ".vue"
  @css_exts ~w(.css)
  @json_ext ".json"

  @doc """
  Compile a source file to browser-ready output.

  ## Options

    * `:target` — downlevel target (e.g. `:es2020`)
    * `:import_source` — JSX import source (e.g. `"vue"`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:minify` — minify output (default: `false`)
    * `:vapor` — use Vue Vapor mode (default: `false`)
    * `:rewrite_import` — function `(specifier -> {:rewrite, new} | :keep)` for import rewriting
    * `:plugins` — list of `Volt.Plugin` modules to run
  """
  @spec compile(String.t(), String.t(), keyword()) :: {:ok, compiled()} | {:error, term()}
  def compile(path, source, opts \\ []) do
    plugins = Keyword.get(opts, :plugins, [])

    {source, opts} =
      case Volt.PluginRunner.load(plugins, path) do
        {:ok, code, _content_type} -> {code, opts}
        {:ok, code} -> {code, opts}
        nil -> {source, opts}
      end

    source = Volt.GlobImport.transform(source, Path.dirname(path))
    ext = Path.extname(path)

    result =
      cond do
        ext == @vue_ext -> compile_vue(path, source, opts)
        ext in Volt.Extensions.js() -> compile_js(path, source, opts)
        Volt.CSSModules.css_module?(path) -> compile_css_module(path, source, opts)
        ext in @css_exts -> compile_css(path, source, opts)
        ext == @json_ext -> compile_json(source)
        true -> {:error, {:unsupported, ext}}
      end

    with {:ok, compiled} <- result do
      compiled = apply_transforms(compiled, path, plugins)

      case Keyword.get(opts, :rewrite_import) do
        rewrite_fn when is_function(rewrite_fn) ->
          rewrite_compiled_imports(compiled, path, rewrite_fn)

        nil ->
          {:ok, compiled}
      end
    end
  end

  defp apply_transforms(compiled, _path, []), do: compiled

  defp apply_transforms(compiled, path, plugins) do
    code = Volt.PluginRunner.transform(plugins, compiled.code, path)
    %{compiled | code: code}
  end

  defp rewrite_compiled_imports(compiled, path, rewrite_fn) do
    filename = Path.basename(path)

    with {:ok, imports_rewritten} <-
           Volt.ImportRewriter.rewrite(compiled.code, filename, rewrite_fn),
         {:ok, workers_rewritten} <-
           Volt.WorkerRewriter.rewrite(imports_rewritten, filename, rewrite_fn) do
      {:ok, %{compiled | code: workers_rewritten}}
    else
      {:error, _} -> {:ok, compiled}
    end
  end

  defp compile_vue(path, source, opts) do
    vapor = Keyword.get(opts, :vapor, false)

    case Vize.compile_sfc(source, filename: Path.basename(path), vapor: vapor) do
      {:ok, result} ->
        {:ok,
         compiled(result.code,
           css: result.css,
           hashes: %{
             template: result.template_hash,
             style: result.style_hash,
             script: result.script_hash
           }
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compile_js(path, source, opts) do
    sourcemap = Keyword.get(opts, :sourcemap, true)

    transform_opts =
      [sourcemap: sourcemap]
      |> maybe_put(:target, Keyword.get(opts, :target))
      |> maybe_put(:import_source, Keyword.get(opts, :import_source))

    case OXC.transform(source, Path.basename(path), transform_opts) do
      {:ok, result} when is_map(result) ->
        {:ok, compiled(result.code, sourcemap: result.sourcemap)}

      {:ok, code} when is_binary(code) ->
        {:ok, compiled(code)}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp compile_css(path, source, opts) do
    minify = Keyword.get(opts, :minify, false)

    result =
      if File.regular?(path) do
        Vize.bundle_css(path, minify: minify)
      else
        Vize.compile_css(source, minify: minify)
      end

    case result do
      {:ok, %{code: code}} ->
        {:ok, compiled(code)}

      {:ok, %{errors: errors}} when errors != [] ->
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compile_css_module(path, source, opts) do
    minify = Keyword.get(opts, :minify, false)
    {:ok, js, scoped_css} = Volt.CSSModules.compile(source, Path.basename(path), minify: minify)
    {:ok, compiled(js, css: scoped_css)}
  end

  defp compile_json(source) do
    {:ok, %{code: "export default #{source};\n", sourcemap: nil, css: nil, hashes: nil}}
  end

  defp compiled(code, opts \\ []) do
    %{
      code: code,
      sourcemap: Keyword.get(opts, :sourcemap),
      css: Keyword.get(opts, :css),
      hashes: Keyword.get(opts, :hashes)
    }
  end

  defp maybe_put(opts, _key, nil), do: opts

  defp maybe_put(opts, key, value) when is_atom(value),
    do: Keyword.put(opts, key, Atom.to_string(value))

  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
