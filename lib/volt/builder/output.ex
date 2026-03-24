defmodule Volt.Builder.Output do
  @moduledoc false

  alias Volt.Builder.Externals

  @doc "Bundle modules into a single JS file and write output."
  def build_single(name, {js_files, css_parts}, outdir, hash, bundle_opts, ctx) do
    File.mkdir_p!(outdir)

    case OXC.bundle(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle(bundle_result)
        js_code = inject_external_preamble(js_code, js_files, ctx)
        js_code = rewrite_worker_urls(js_code, entry_worker_map(js_files, ctx), name)
        js_code = Volt.PluginRunner.render_chunk(ctx.plugins, js_code, %{name: name, type: :entry})

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
  def build_chunks(entry, name, modules, dep_map, {js_files, css_parts}, outdir, hash, bundle_opts, ctx) do
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
        chunk_js = select_chunk_files(chunk.modules, js_map)
        code = inject_external_preamble(code, chunk_js, ctx)
        code = rewrite_dynamic_imports(code, graph.module_to_chunk, chunk_url_map)
        code = rewrite_worker_urls(code, entry_worker_map(chunk_js, ctx), chunk_id)
        code = Volt.PluginRunner.render_chunk(ctx.plugins, code, %{name: chunk_id, type: chunk.type})

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
        filename = Path.basename(js.path)
        Map.put(acc, filename, %{"file" => filename, "src" => filename})
      end)
      |> Map.put("#{name}.js", %{"file" => Path.basename(entry_js.path), "src" => "#{name}.js"})

    manifest =
      if css_result do
        css_filename = Path.basename(css_result.path)

        manifest
        |> put_in(["#{name}.js", "css"], [css_filename])
        |> Map.put("#{name}.css", %{
          "file" => css_filename,
          "src" => "#{name}.css",
          "assets" => [css_filename]
        })
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
        worker_patches = collect_worker_patches(ast, module_to_chunk, chunk_url_map)
        all_patches = patches ++ worker_patches
        if all_patches == [], do: code, else: OXC.patch_string(code, all_patches)

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

  defp collect_worker_patches(ast, module_to_chunk, chunk_url_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: "NewExpression", callee: %{type: "Identifier", name: worker_type}, arguments: [first_arg | _]} = node, patches
        when worker_type in ["Worker", "SharedWorker"] ->
          case worker_patch(first_arg, module_to_chunk, chunk_url_map) do
            nil -> {node, patches}
            patch -> {node, [patch | patches]}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp find_chunk_url(spec, module_to_chunk, chunk_url_map) do
    spec_normalized =
      spec
      |> String.trim_leading("./")
      |> String.trim_leading("../")
      |> Path.rootname()

    chunk_id =
      Enum.find_value(module_to_chunk, fn {mod_path, chunk_id} ->
        mod_normalized = Path.rootname(mod_path)

        if String.ends_with?(mod_normalized, spec_normalized) do
          chunk_id
        end
      end)

    if chunk_id, do: chunk_url_map[chunk_id]
  end

  defp worker_patch(
         %{type: "NewExpression", callee: %{type: "Identifier", name: "URL"}, arguments: [source_node, %{type: "MemberExpression", object: %{type: "MetaProperty"}} | _]},
         module_to_chunk,
         chunk_url_map
       ) do
    case source_node do
      %{value: spec, start: s, end: e} when is_binary(spec) and is_integer(s) and is_integer(e) ->
        case find_chunk_url(spec, module_to_chunk, chunk_url_map) do
          nil -> nil
          url -> %{start: s, end: e, change: "'./#{url}'"}
        end

      %{type: "StringLiteral", value: spec, start: s, end: e}
      when is_binary(spec) and is_integer(s) and is_integer(e) ->
        case find_chunk_url(spec, module_to_chunk, chunk_url_map) do
          nil -> nil
          url -> %{start: s, end: e, change: "'./#{url}'"}
        end

      _ ->
        nil
    end
  end

  defp worker_patch(_, _, _), do: nil

  defp entry_worker_map(js_files, ctx) do
    importers = Enum.map(js_files, fn {label, _code} -> label end)

    ctx.workers
    |> Enum.filter(fn {importer, _} -> Path.basename(importer) in importers end)
    |> Enum.flat_map(fn {_importer, spec_map} -> Map.to_list(spec_map) end)
    |> Map.new(fn {specifier, resolved_path} ->
      {specifier, Map.get(ctx.worker_results, resolved_path)}
    end)
    |> Enum.reject(fn {_specifier, filename} -> is_nil(filename) end)
    |> Map.new()
  end

  defp rewrite_worker_urls(code, worker_map, _filename) when worker_map == %{}, do: code

  defp rewrite_worker_urls(code, worker_map, filename) do
    case Volt.WorkerRewriter.rewrite(code, to_string(filename), fn specifier ->
           case Map.fetch(worker_map, specifier) do
             {:ok, worker_filename} -> {:rewrite, "./#{worker_filename}"}
             :error -> :keep
           end
         end) do
      {:ok, rewritten} -> rewritten
      {:error, _} -> code
    end
  end

  # ── External globals ─────────────────────────────────────────────────

  defp inject_external_preamble(code, js_files, ctx) do
    if MapSet.size(ctx.external_set) == 0 do
      code
    else
      external_imports = Externals.collect_imports(js_files, ctx.external_set)

      if map_size(external_imports) == 0 do
        code
      else
        preamble = Externals.generate_preamble(external_imports, ctx.external_globals)
        inject_into_iife(code, preamble)
      end
    end
  end

  defp inject_into_iife(code, preamble) do
    case find_iife_body_start(code) do
      {:ok, offset} ->
        binary_part(code, 0, offset) <> "\n" <> preamble <> binary_part(code, offset, byte_size(code) - offset)

      :error ->
        preamble <> code
    end
  end

  defp find_iife_body_start(code) do
    case OXC.parse(code, "iife.js") do
      {:ok, ast} ->
        {_ast, result} =
          OXC.postwalk(ast, :error, fn
            %{type: "ArrowFunctionExpression", body: %{type: "FunctionBody", start: start}} = node, :error ->
              {node, {:ok, start + 1}}

            node, acc ->
              {node, acc}
          end)

        result

      {:error, _} ->
        :error
    end
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

  def build_style_entry(name, css_code, outdir, hash) do
    File.mkdir_p!(outdir)

    css_filename = hashed_name(name, css_code, ".css", hash)
    css_path = Path.join(outdir, css_filename)
    File.write!(css_path, css_code)

    manifest = %{
      "#{name}.css" => %{
        "file" => css_filename,
        "src" => "#{name}.css",
        "assets" => [css_filename]
      }
    }

    write_manifest(outdir, manifest)

    {:ok,
     %{
       js: [],
       css: %{path: css_path, size: byte_size(css_code)},
       manifest: manifest
     }}
  end

  def write_manifest(outdir, manifest) do
    File.write!(Path.join(outdir, "manifest.json"), :json.encode(manifest))
  end

  def build_manifest(name, js_filename, css_result) do
    js_entry = %{
      "file" => js_filename,
      "src" => "#{name}.js"
    }

    manifest = %{"#{name}.js" => js_entry}

    if css_result do
      css_filename = Path.basename(css_result.path)

      manifest
      |> put_in(["#{name}.js", "css"], [css_filename])
      |> Map.put("#{name}.css", %{
        "file" => css_filename,
        "src" => "#{name}.css",
        "assets" => [css_filename]
      })
    else
      manifest
    end
  end

  def hashed_name(name, content, ext, true) do
    "#{name}-#{Volt.Format.content_hash(content)}#{ext}"
  end

  def hashed_name(name, _content, ext, false), do: "#{name}#{ext}"

  defp extract_bundle(result) when is_binary(result), do: {result, nil}
  defp extract_bundle(%{code: code, sourcemap: map}), do: {code, map}
end
