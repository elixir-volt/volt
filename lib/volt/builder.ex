defmodule Volt.Builder do
  @moduledoc """
  Production build — resolve dependencies, bundle, minify, and write assets.

  Walks the dependency graph from entry files, compiles everything through
  the Pipeline, bundles JS with `OXC.bundle/2`, collects CSS, and writes
  content-hashed output files with a manifest.
  """

  @extensions ["", ".ts", ".tsx", ".js", ".jsx", ".mts", ".mjs", ".vue"]
  @index_files ~w(/index.ts /index.tsx /index.js /index.jsx)

  @type build_result :: %{
          js: %{path: String.t(), size: non_neg_integer()},
          css: %{path: String.t(), size: non_neg_integer()} | nil,
          manifest: %{String.t() => String.t()}
        }

  @doc """
  Build production assets from an entry file.

  ## Options

    * `:entry` — entry file path (required)
    * `:outdir` — output directory (default: `"priv/static/assets"`)
    * `:target` — JS target (e.g. `"es2020"`)
    * `:minify` — minify output (default: `true`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:define` — compile-time replacements
    * `:node_modules` — path to node_modules (default: auto-detect)
    * `:name` — output base name (default: derived from entry filename)
  """
  @spec build(keyword()) :: {:ok, build_result()} | {:error, term()}
  def build(opts) do
    entry = Keyword.fetch!(opts, :entry) |> Path.expand()
    outdir = Keyword.get(opts, :outdir, "priv/static/assets") |> Path.expand()
    target = Keyword.get(opts, :target, "")
    minify = Keyword.get(opts, :minify, true)
    sourcemap = Keyword.get(opts, :sourcemap, true)
    define = Keyword.get(opts, :define, %{})
    node_modules = Keyword.get(opts, :node_modules) || find_node_modules(Path.dirname(entry))
    name = Keyword.get(opts, :name, entry |> Path.basename() |> Path.rootname())

    with {:ok, modules} <- collect_modules(entry, node_modules),
         {:ok, {js_files, css_parts}} <- compile_all(modules, target) do
      bundle_opts = [
        minify: minify,
        sourcemap: sourcemap,
        target: target,
        define: define
      ]

      write_output(js_files, css_parts, outdir, name, bundle_opts)
    end
  end

  defp collect_modules(entry_path, node_modules) do
    label = Path.basename(entry_path)

    case do_collect(entry_path, label, node_modules, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, label, node_modules, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      case File.read(abs_path) do
        {:ok, source} ->
          seen = MapSet.put(seen, abs_path)
          files = [{abs_path, label, source} | files]

          case extract_imports(source, abs_path) do
            {:ok, specifiers} ->
              collect_imports(specifiers, abs_path, node_modules, files, seen)

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

  defp collect_imports([], _importer, _node_modules, files, seen) do
    {:ok, files, seen}
  end

  defp collect_imports([specifier | rest], importer, node_modules, files, seen) do
    case resolve_specifier(specifier, importer, node_modules) do
      :skip ->
        collect_imports(rest, importer, node_modules, files, seen)

      {:ok, resolved_path} ->
        label = if relative?(specifier), do: Path.basename(resolved_path), else: specifier

        case do_collect(resolved_path, label, node_modules, files, seen) do
          {:ok, files, seen} ->
            collect_imports(rest, importer, node_modules, files, seen)

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp compile_all(modules, target) do
    result =
      Enum.reduce_while(modules, {[], []}, fn {path, label, source}, {js_acc, css_acc} ->
        case compile_module(path, label, source, target) do
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

  defp compile_module(path, _label, source, target) do
    ext = Path.extname(path)

    if ext == ".vue" do
      compile_vue_module(source, path)
    else
      compile_js_module(source, path, target)
    end
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

  defp write_output(js_files, css_parts, outdir, name, bundle_opts) do
    File.mkdir_p!(outdir)

    case OXC.bundle(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle(bundle_result)
        js_hash = content_hash(js_code)
        js_filename = "#{name}-#{js_hash}.js"
        js_path = Path.join(outdir, js_filename)
        File.write!(js_path, js_code)

        manifest = %{
          "#{name}.js" => js_filename
        }

        if js_sourcemap do
          map_filename = "#{js_filename}.map"
          File.write!(Path.join(outdir, map_filename), js_sourcemap)
        end

        css_result =
          if css_parts != [] do
            css_code = Enum.join(css_parts, "\n")

            css_code =
              case Vize.compile_css(css_code, minify: bundle_opts[:minify] || false) do
                {:ok, %{code: minified}} -> minified
                _ -> css_code
              end

            css_hash = content_hash(css_code)
            css_filename = "#{name}-#{css_hash}.css"
            css_path = Path.join(outdir, css_filename)
            File.write!(css_path, css_code)
            %{path: css_path, size: byte_size(css_code)}
          end

        manifest =
          if css_result do
            css_hash = content_hash(File.read!(css_result.path))
            Map.put(manifest, "#{name}.css", "#{name}-#{css_hash}.css")
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

  defp resolve_specifier(specifier, importer, node_modules) do
    cond do
      String.starts_with?(specifier, "node:") -> :skip
      relative?(specifier) -> resolve_relative(specifier, importer)
      true -> resolve_bare(specifier, node_modules)
    end
  end

  defp relative?(specifier) do
    String.starts_with?(specifier, "./") or String.starts_with?(specifier, "../")
  end

  defp resolve_relative(specifier, importer) do
    base = Path.join(Path.dirname(importer), specifier) |> Path.expand()
    try_resolve(base)
  end

  defp resolve_bare(_specifier, nil), do: :skip

  defp resolve_bare(specifier, node_modules) do
    {package_name, subpath} = split_specifier(specifier)
    package_dir = Path.join(node_modules, package_name)

    if subpath do
      try_resolve(Path.join(package_dir, subpath))
    else
      resolve_package_entry(package_dir, package_name)
    end
  end

  defp split_specifier("@" <> rest) do
    case String.split(rest, "/", parts: 3) do
      [scope, name, subpath] -> {"@#{scope}/#{name}", subpath}
      [scope, name] -> {"@#{scope}/#{name}", nil}
      _ -> {"@#{rest}", nil}
    end
  end

  defp split_specifier(specifier) do
    case String.split(specifier, "/", parts: 2) do
      [name, subpath] -> {name, subpath}
      [name] -> {name, nil}
    end
  end

  defp resolve_package_entry(package_dir, package_name) do
    pkg_json = Path.join(package_dir, "package.json")

    case File.read(pkg_json) do
      {:ok, content} ->
        pkg = :json.decode(content)
        entry = resolve_exports(pkg) || pkg["module"] || pkg["main"] || "index.js"
        try_resolve(Path.expand(Path.join(package_dir, entry)))

      {:error, _} ->
        {:error, {:not_found, package_name}}
    end
  end

  defp resolve_exports(%{"exports" => exports}) when is_binary(exports), do: exports
  defp resolve_exports(%{"exports" => %{"." => entry}}) when is_binary(entry), do: entry

  defp resolve_exports(%{"exports" => %{"." => conditions}}) when is_map(conditions) do
    conditions["import"] || conditions["default"] || conditions["require"]
  end

  defp resolve_exports(_), do: nil

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

  defp find_node_modules(dir) do
    candidate = Path.join(dir, "node_modules")

    cond do
      File.dir?(candidate) -> candidate
      dir == "/" -> nil
      true -> find_node_modules(Path.dirname(dir))
    end
  end
end
