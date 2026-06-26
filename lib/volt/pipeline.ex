defmodule Volt.Pipeline do
  @moduledoc """
  Compile source files to browser-ready JavaScript and CSS.

  Dispatches to OXC for JS/TS/JSX/TSX and Vize for Vue SFCs and CSS, then runs
  the shared JavaScript post-processing phase. Framework and plugin output flows
  through the same post-processing as ordinary source files, so features such as
  asset URL rewriting, dynamic import variables, `import.meta.glob()`,
  `import.meta.env`, and worker/import specifier rewriting behave consistently.
  """

  @type rewrite_fn :: (String.t() -> {:rewrite, String.t()} | :keep)

  @type compiled :: Volt.Pipeline.Result.t()

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
    * `:define` — compile-time replacements for `import.meta.env`
  """
  @spec compile(String.t(), String.t(), keyword()) :: {:ok, compiled()} | {:error, term()}
  def compile(path, source, opts \\ []) do
    plugins = Keyword.get(opts, :plugins, [])

    {source, content_type, compile_path} = source_context(path, source, plugins)
    {base_path, _query} = Volt.URL.split_query(compile_path)
    ext = Path.extname(base_path)

    result =
      cond do
        plugin_result = Volt.PluginRunner.compile(plugins, path, source, opts) ->
          plugin_result

        Volt.MIME.javascript?(content_type) ->
          compile_js(compile_path, source, opts)

        Volt.MIME.css?(content_type) ->
          compile_css(compile_path, source, opts)

        ext in Volt.JS.Extensions.js() ->
          compile_js(compile_path, source, opts)

        Volt.CSS.Modules.css_module?(base_path) ->
          compile_css_module(compile_path, source, opts)

        ext in @css_exts ->
          compile_css(compile_path, source, opts)

        ext == @json_ext ->
          compile_json(source)

        true ->
          {:error, {:unsupported, ext}}
      end

    with {:ok, compiled} <- result,
         compiled = normalize_result(compiled),
         compiled = apply_transforms(compiled, path, plugins),
         {:ok, compiled} <- postprocess_javascript(compiled, path, opts) do
      case Keyword.get(opts, :rewrite_import) do
        rewrite_fn when is_function(rewrite_fn) ->
          rewrite_compiled_imports(compiled, path, rewrite_fn)

        nil ->
          {:ok, compiled}
      end
    end
  end

  defp source_context(path, source, plugins) do
    case Volt.PluginRunner.embedded_module(plugins, path) do
      {:ok, module, parent} ->
        compile_path = parent <> ".#{module.type}#{module.index}#{module.extension}"
        {module.source, Volt.Plugin.EmbeddedModule.content_type(module), compile_path}

      {:error, _} ->
        {source, nil, path}

      nil ->
        {base_path, _query} = Volt.URL.split_query(path)

        case Volt.PluginRunner.load(plugins, path) do
          {:ok, code, content_type} -> {code, content_type, path}
          {:ok, code} -> {code, Volt.MIME.javascript(), path}
          nil -> {source, nil, base_path}
        end
    end
  end

  defp normalize_result(%Volt.Pipeline.Result{} = compiled), do: compiled

  defp normalize_result(compiled) when is_map(compiled) do
    struct(
      Volt.Pipeline.Result,
      Map.take(compiled, [:code, :type, :sourcemap, :css, :hashes, :warnings])
    )
  end

  defp apply_transforms(compiled, _path, []), do: compiled

  defp apply_transforms(compiled, path, plugins) do
    code = Volt.PluginRunner.transform(plugins, compiled.code, path)
    put_code(compiled, code)
  end

  defp postprocess_javascript(%{type: :js} = compiled, path, opts) do
    filename = Path.basename(path)

    code =
      compiled.code
      |> Volt.JS.Transforms.AssetURLs.rewrite(filename)
      |> Volt.JS.Transforms.DynamicImports.transform(filename)
      |> Volt.JS.Transforms.GlobImports.transform(Path.dirname(path), filename)

    with {:ok, code} <-
           Volt.JS.Transforms.ImportMetaEnv.inject(
             code,
             filename,
             Keyword.get(opts, :define, %{})
           ) do
      {:ok, put_code(compiled, code)}
    end
  end

  defp postprocess_javascript(compiled, _path, _opts), do: {:ok, compiled}

  defp rewrite_compiled_imports(compiled, path, rewrite_fn) do
    filename = Path.basename(path)

    with {:ok, imports_rewritten} <-
           Volt.JS.Transforms.Imports.rewrite(compiled.code, filename, rewrite_fn),
         {:ok, workers_rewritten} <-
           Volt.JS.Transforms.Workers.rewrite(imports_rewritten, filename, rewrite_fn) do
      {:ok, put_code(compiled, workers_rewritten)}
    else
      {:error, _} -> {:ok, compiled}
    end
  end

  defp put_code(%{code: code} = compiled, code), do: compiled
  defp put_code(compiled, code), do: %{compiled | code: code, sourcemap: nil}

  defp compile_js(path, source, opts) do
    sourcemap = Keyword.get(opts, :sourcemap, true)

    transform_opts =
      [sourcemap: sourcemap]
      |> maybe_put(:target, Keyword.get(opts, :target))
      |> maybe_put(:import_source, Keyword.get(opts, :import_source))

    filename =
      Volt.JS.Extensions.apply_loader(Path.basename(path), Keyword.get(opts, :loaders, %{}))

    case OXC.transform(source, filename, transform_opts) do
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
        Vize.CSS.bundle(path, minify: minify)
      else
        Vize.CSS.compile(source, minify: minify)
      end

    case result do
      {:ok, %{errors: [_ | _] = errors}} ->
        {:error, errors}

      {:ok, %{code: code}} ->
        {:ok, compiled(code, type: :css)}
    end
  end

  defp compile_css_module(path, source, opts) do
    minify = Keyword.get(opts, :minify, false)
    {:ok, js, scoped_css} = Volt.CSS.Modules.compile(source, Path.basename(path), minify: minify)
    {:ok, compiled(js, css: scoped_css)}
  end

  defp compile_json(source) do
    {:ok, compiled("export default #{source};\n")}
  end

  defp compiled(code, opts \\ []) do
    %Volt.Pipeline.Result{
      code: code,
      type: Keyword.get(opts, :type, :js),
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
