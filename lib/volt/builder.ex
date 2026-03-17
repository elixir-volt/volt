defmodule Volt.Builder do
  @moduledoc """
  Production build — resolve dependencies, bundle, minify, and write assets.

  Walks the dependency graph from entry files, compiles everything through
  the Pipeline, bundles JS with `OXC.bundle/2`, collects CSS, and writes
  content-hashed output files with a manifest.
  """

  alias Volt.PackageResolver

  @extensions ["", ".ts", ".tsx", ".js", ".jsx", ".mts", ".mjs", ".vue", ".json"]
  @index_files ~w(/index.ts /index.tsx /index.js /index.jsx)

  @type build_result :: %{
          js: %{path: String.t(), size: non_neg_integer()},
          css: %{path: String.t(), size: non_neg_integer()} | nil,
          manifest: %{String.t() => String.t()}
        }

  @doc """
  Build production assets from one or more entry files.

  ## Options

    * `:entry` — entry file path or list of paths (required)
    * `:outdir` — output directory (default: `"priv/static/assets"`)
    * `:target` — JS target (e.g. `"es2020"`)
    * `:minify` — minify output (default: `true`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:define` — compile-time replacements
    * `:node_modules` — path to node_modules (default: auto-detect)
    * `:resolve_dirs` — additional directories to resolve bare specifiers (e.g. `["deps"]`)
    * `:name` — output base name (default: derived from entry filename)
    * `:aliases` — import alias map (e.g. `%{"@" => "assets/src"}`)
    * `:plugins` — list of `Volt.Plugin` modules
    * `:mode` — build mode for env variables (default: `"production"`)
  """
  @spec build(keyword()) :: {:ok, build_result()} | {:error, term()}
  def build(opts) do
    entries = opts |> Keyword.fetch!(:entry) |> List.wrap() |> Enum.map(&Path.expand/1)
    outdir = Keyword.get(opts, :outdir, "priv/static/assets") |> Path.expand()
    target = Keyword.get(opts, :target, "")
    minify = Keyword.get(opts, :minify, true)
    sourcemap = Keyword.get(opts, :sourcemap, true)
    define = Keyword.get(opts, :define, %{})
    mode = Keyword.get(opts, :mode, "production")
    aliases = Keyword.get(opts, :aliases, %{})
    plugins = Keyword.get(opts, :plugins, [])

    first_entry = hd(entries)
    node_modules = Keyword.get(opts, :node_modules) || PackageResolver.find_node_modules(Path.dirname(first_entry))
    resolve_dirs = Keyword.get(opts, :resolve_dirs, []) |> Enum.map(&Path.expand/1)
    hash = Keyword.get(opts, :hash, true)
    name = Keyword.get(opts, :name)

    env_define = Volt.Env.define(mode: mode, root: File.cwd!())
    define = Map.merge(env_define, define)

    results =
      Enum.map(entries, fn entry ->
        entry_name = name || entry |> Path.basename() |> Path.rootname()

        with {:ok, modules} <- collect_modules(entry, node_modules, resolve_dirs, aliases, plugins),
             {:ok, {js_files, css_parts}} <- compile_all(modules, target, plugins) do
          bundle_opts = [
            minify: minify,
            sourcemap: sourcemap,
            target: target,
            define: define
          ]

          write_output(js_files, css_parts, outdir, entry_name, hash, bundle_opts, plugins)
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} when successes != [] ->
        if length(successes) == 1 do
          hd(successes)
        else
          merged = merge_build_results(successes)
          {:ok, merged}
        end

      {_, [first_error | _]} ->
        first_error
    end
  end

  defp merge_build_results(results) do
    Enum.reduce(results, %{js: [], css: nil, manifest: %{}}, fn {:ok, result}, acc ->
      js = [result.js | acc.js]
      css = result.css || acc.css
      manifest = Map.merge(acc.manifest, result.manifest)
      %{js: js, css: css, manifest: manifest}
    end)
  end

  defp collect_modules(entry_path, node_modules, resolve_dirs, aliases, plugins) do
    label = Path.basename(entry_path)
    ctx = %{node_modules: node_modules, resolve_dirs: resolve_dirs, aliases: aliases, plugins: plugins}

    case do_collect(entry_path, label, ctx, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, label, ctx, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      case File.read(abs_path) do
        {:ok, source} ->
          seen = MapSet.put(seen, abs_path)
          files = [{abs_path, label, source} | files]

          case extract_imports(source, abs_path) do
            {:ok, specifiers} ->
              collect_imports(specifiers, abs_path, ctx, files, seen)

            {:error, _} = error ->
              error
          end

        {:error, reason} ->
          {:error, {:file_read_error, abs_path, reason}}
      end
    end
  end

  defp extract_imports(source, path) do
    ext = Path.extname(path)
    filename = Path.basename(path)

    if ext == ".vue" do
      extract_vue_imports(source)
    else
      OXC.imports(source, filename)
    end
  end

  defp extract_vue_imports(source) do
    case Vize.parse_sfc(source) do
      {:ok, descriptor} ->
        imports =
          [descriptor.script, descriptor.script_setup]
          |> Enum.reject(&is_nil/1)
          |> Enum.flat_map(fn block ->
            lang = block[:lang] || "js"

            case OXC.imports(block.content, "script.#{lang}") do
              {:ok, imports} -> imports
              {:error, _} -> []
            end
          end)

        {:ok, imports}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp collect_imports([], _importer, _ctx, files, seen) do
    {:ok, files, seen}
  end

  defp collect_imports([specifier | rest], importer, ctx, files, seen) do
    case resolve_specifier(specifier, importer, ctx) do
      :skip ->
        collect_imports(rest, importer, ctx, files, seen)

      {:ok, resolved_path} ->
        label = if relative?(specifier), do: Path.basename(resolved_path), else: specifier

        case do_collect(resolved_path, label, ctx, files, seen) do
          {:ok, files, seen} ->
            collect_imports(rest, importer, ctx, files, seen)

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp compile_all(modules, target, plugins) do
    result =
      Enum.reduce_while(modules, {[], []}, fn {path, label, source}, {js_acc, css_acc} ->
        case compile_module(path, label, source, target, plugins) do
          {:ok, js, css} ->
            {:cont, {[{label, js} | js_acc], if(css, do: [css | css_acc], else: css_acc)}}

          {:error, _} = error ->
            {:halt, error}
        end
      end)

    case result do
      {js_files, css_parts} when is_list(js_files) ->
        {:ok, {Enum.reverse(js_files), Enum.reverse(css_parts)}}

      {:error, _} = error ->
        error
    end
  end

  defp compile_module(path, _label, source, target, plugins) do
    ext = Path.extname(path)

    cond do
      ext == ".vue" ->
        compile_vue_module(source, path)

      Volt.CSSModules.css_module?(path) ->
        compile_css_module(source, path)

      ext == ".json" ->
        {:ok, "export default #{source};\n", nil}

      Volt.Assets.asset?(path) ->
        case Volt.Assets.to_js_module(path) do
          {:ok, js} -> {:ok, js, nil}
          {:error, _} = error -> error
        end

      true ->
        result = compile_js_module(source, path, target)
        with {:ok, js, css} <- result do
          js = Volt.PluginRunner.transform(plugins, js, path)
          {:ok, js, css}
        end
    end
  end

  defp compile_css_module(source, path) do
    {:ok, js, scoped_css} = Volt.CSSModules.compile(source, Path.basename(path))
    {:ok, js, scoped_css}
  end

  defp compile_vue_module(source, path) do
    case Vize.compile_sfc(source, filename: Path.basename(path)) do
      {:ok, result} -> {:ok, result.code, result.css}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compile_js_module(source, path, target) do
    case OXC.transform(source, Path.basename(path), target: target) do
      {:ok, code} when is_binary(code) -> {:ok, code, nil}
      {:ok, %{code: code}} -> {:ok, code, nil}
      {:error, errors} -> {:error, errors}
    end
  end

  defp write_output(js_files, css_parts, outdir, name, hash?, bundle_opts, plugins) do
    File.mkdir_p!(outdir)

    case OXC.bundle(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle(bundle_result)
        js_code = Volt.PluginRunner.render_chunk(plugins, js_code, %{name: name, type: :js})
        js_filename = if hash?, do: "#{name}-#{content_hash(js_code)}.js", else: "#{name}.js"
        js_path = Path.join(outdir, js_filename)
        File.write!(js_path, js_code)

        manifest = %{"#{name}.js" => js_filename}

        if js_sourcemap do
          File.write!(Path.join(outdir, "#{js_filename}.map"), js_sourcemap)
        end

        css_result =
          if css_parts != [] do
            css_code = Enum.join(css_parts, "\n")

            css_code =
              case Vize.compile_css(css_code, minify: bundle_opts[:minify] || false) do
                {:ok, %{code: minified}} -> minified
                _ -> css_code
              end

            css_filename =
              if hash?, do: "#{name}-#{content_hash(css_code)}.css", else: "#{name}.css"

            css_path = Path.join(outdir, css_filename)
            File.write!(css_path, css_code)
            %{path: css_path, size: byte_size(css_code)}
          end

        manifest =
          if css_result do
            css_filename = Path.basename(css_result.path)
            Map.put(manifest, "#{name}.css", css_filename)
          else
            manifest
          end

        manifest_path = Path.join(outdir, "manifest.json")
        File.write!(manifest_path, :json.encode(manifest))

        {:ok,
         %{
           js: %{path: js_path, size: byte_size(js_code)},
           css: css_result,
           manifest: manifest
         }}

      {:error, _} = error ->
        error
    end
  end

  defp extract_bundle(result) when is_binary(result), do: {result, nil}
  defp extract_bundle(%{code: code, sourcemap: map}), do: {code, map}

  defp content_hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  defp resolve_specifier(specifier, importer, ctx) do
    case Volt.PluginRunner.resolve(ctx.plugins, specifier, importer) do
      {:ok, _} = resolved ->
        resolved

      nil ->
        case Volt.Resolver.resolve(specifier, ctx.aliases) do
          {:ok, aliased} ->
            resolve_relative_path(aliased, importer)

          :pass ->
            cond do
              String.starts_with?(specifier, "node:") -> :skip
              relative?(specifier) -> resolve_relative(specifier, importer)
              true -> resolve_bare(specifier, ctx.node_modules, ctx.resolve_dirs)
            end
        end
    end
  end

  defp resolve_relative_path(path, _importer) do
    try_resolve(Path.expand(path))
  end

  defp relative?(specifier) do
    String.starts_with?(specifier, "./") or String.starts_with?(specifier, "../")
  end

  defp resolve_relative(specifier, importer) do
    base = Path.join(Path.dirname(importer), specifier) |> Path.expand()
    try_resolve(base)
  end

  defp resolve_bare(specifier, node_modules, resolve_dirs) do
    dirs =
      if node_modules, do: [node_modules | resolve_dirs], else: resolve_dirs

    Enum.find_value(dirs, :skip, fn dir ->
      case resolve_in_dir(specifier, dir) do
        {:ok, _} = found -> found
        _ -> nil
      end
    end)
  end

  defp resolve_in_dir(specifier, dir) do
    {package_name, subpath} = PackageResolver.split_specifier(specifier)
    package_dir = Path.join(dir, package_name)

    if subpath do
      try_resolve(Path.join(package_dir, subpath))
    else
      PackageResolver.resolve_package_entry(package_dir, package_name, &try_resolve/1)
    end
  end

  defp try_resolve(base) do
    Enum.find_value(@extensions, fn ext ->
      path = base <> ext
      if File.regular?(path), do: {:ok, path}
    end) ||
      Enum.find_value(@index_files, fn idx ->
        path = base <> idx
        if File.regular?(path), do: {:ok, path}
      end) ||
      {:error, {:not_found, base}}
  end
end
