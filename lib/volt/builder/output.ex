defmodule Volt.Builder.Output do
  @moduledoc false

  @doc "Bundle modules into a single JS file and write output."
  def build_single(name, {js_files, css_parts}, outdir, hash, bundle_opts, plugins) do
    File.mkdir_p!(outdir)

    case OXC.bundle(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle(bundle_result)
        js_code = Volt.PluginRunner.render_chunk(plugins, js_code, %{name: name, type: :entry})

        js_filename = hashed_name(name, js_code, ".js", hash)
        write_js(outdir, js_filename, js_code, js_sourcemap)

        css_result = write_css(css_parts, outdir, name, hash, bundle_opts)
        manifest = build_manifest(name, js_filename, css_result)
        write_manifest(outdir, manifest)

        {:ok, %{
          js: %{path: Path.join(outdir, js_filename), size: byte_size(js_code)},
          css: css_result,
          manifest: manifest
        }}

      {:error, _} = error ->
        error
    end
  end

  @doc "Bundle modules into separate chunks based on the chunk graph."
  def build_chunks(entry, name, modules, dep_map, {js_files, css_parts}, outdir, hash, bundle_opts, plugins) do
    File.mkdir_p!(outdir)

    graph = Volt.ChunkGraph.build(entry, modules, dep_map)
    js_map = Map.new(js_files)

    chunk_filenames =
      Enum.reduce(graph.chunks, %{}, fn {chunk_id, chunk}, acc ->
        chunk_js = select_chunk_files(chunk.modules, js_map)

        if chunk_js == [] do
          acc
        else
          case OXC.bundle(chunk_js, bundle_opts) do
            {:ok, result} ->
              {code, _} = extract_bundle(result)
              chunk_name = if chunk.type == :entry, do: name, else: "#{name}-#{chunk_id}"
              filename = hashed_name(chunk_name, code, ".js", hash)
              Map.put(acc, chunk_id, {filename, code})

            {:error, _} ->
              acc
          end
        end
      end)

    chunk_url_map =
      Map.new(chunk_filenames, fn {chunk_id, {filename, _}} -> {chunk_id, filename} end)

    js_results =
      Enum.map(chunk_filenames, fn {chunk_id, {_filename, code}} ->
        chunk = graph.chunks[chunk_id]
        code = rewrite_dynamic_imports(code, graph.module_to_chunk, chunk_url_map)
        code = Volt.PluginRunner.render_chunk(plugins, code, %{name: chunk_id, type: chunk.type})

        filename = hashed_name(
          (if chunk.type == :entry, do: name, else: "#{name}-#{chunk_id}"),
          code, ".js", hash
        )
        write_js(outdir, filename, code, nil)
        %{path: Path.join(outdir, filename), size: byte_size(code), chunk_id: chunk_id, type: chunk.type}
      end)

    entry_js = Enum.find(js_results, &(&1.type == :entry)) || hd(js_results)
    css_result = write_css(css_parts, outdir, name, hash, bundle_opts)

    manifest =
      js_results
      |> Enum.reduce(%{}, fn js, acc ->
        Map.put(acc, Path.basename(js.path), Path.basename(js.path))
      end)
      |> Map.put("#{name}.js", Path.basename(entry_js.path))

    manifest =
      if css_result do
        Map.put(manifest, "#{name}.css", Path.basename(css_result.path))
      else
        manifest
      end

    write_manifest(outdir, manifest)

    {:ok, %{
      js: entry_js,
      css: css_result,
      manifest: manifest,
      chunks: js_results
    }}
  end

  defp select_chunk_files(module_paths, js_map) do
    module_paths
    |> Enum.map(fn mod_path ->
      label = Path.basename(mod_path)
      {label, Map.get(js_map, label, "")}
    end)
    |> Enum.reject(fn {_, code} -> code == "" end)
  end

  defp rewrite_dynamic_imports(code, module_to_chunk, chunk_url_map) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        patches = collect_dynamic_import_patches(ast, module_to_chunk, chunk_url_map)
        if patches == [], do: code, else: OXC.patch_string(code, patches)

      {:error, _} ->
        code
    end
  end

  defp collect_dynamic_import_patches(ast, module_to_chunk, chunk_url_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: "ImportExpression", source: %{type: "Literal", value: spec, start: s, end: e}} = node, patches
        when is_binary(spec) ->
          case find_chunk_url(spec, module_to_chunk, chunk_url_map) do
            nil -> {node, patches}
            url -> {node, [%{start: s, end: e, change: "'./#{url}'"} | patches]}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp find_chunk_url(spec, module_to_chunk, chunk_url_map) do
    resolved =
      Enum.find_value(module_to_chunk, fn {mod_path, chunk_id} ->
        basename = Path.basename(mod_path, Path.extname(mod_path))
        spec_base = spec |> String.trim_leading("./") |> String.trim_leading("../") |> Path.rootname()
        if basename == Path.basename(spec_base), do: chunk_id
      end)

    if resolved, do: chunk_url_map[resolved]
  end

  # ── File writing ────────────────────────────────────────────────────

  def write_js(outdir, filename, code, sourcemap) do
    File.write!(Path.join(outdir, filename), code)
    if sourcemap, do: File.write!(Path.join(outdir, "#{filename}.map"), sourcemap)
  end

  def write_css([], _outdir, _name, _hash, _bundle_opts), do: nil

  def write_css(css_parts, outdir, name, hash, bundle_opts) do
    css_code = Enum.join(css_parts, "\n")

    css_code =
      case Vize.compile_css(css_code, minify: bundle_opts[:minify] || false) do
        {:ok, %{code: minified}} -> minified
        _ -> css_code
      end

    css_filename = hashed_name(name, css_code, ".css", hash)
    css_path = Path.join(outdir, css_filename)
    File.write!(css_path, css_code)
    %{path: css_path, size: byte_size(css_code)}
  end

  def write_manifest(outdir, manifest) do
    File.write!(Path.join(outdir, "manifest.json"), :json.encode(manifest))
  end

  def build_manifest(name, js_filename, css_result) do
    manifest = %{"#{name}.js" => js_filename}

    if css_result do
      Map.put(manifest, "#{name}.css", Path.basename(css_result.path))
    else
      manifest
    end
  end

  def hashed_name(name, content, ext, true) do
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
    "#{name}-#{hash}#{ext}"
  end

  def hashed_name(name, _content, ext, false), do: "#{name}#{ext}"

  defp extract_bundle(result) when is_binary(result), do: {result, nil}
  defp extract_bundle(%{code: code, sourcemap: map}), do: {code, map}
end
