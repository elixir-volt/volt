defmodule Volt.Builder.Output do
  @moduledoc false

  alias Volt.Builder.{Writer, BundleResult, Rewriter}

  @doc "Bundle modules into a single JS file and write output."
  def build_single(entry, name, {js_files, css_parts}, build_ctx) do
    %{outdir: outdir, hash: hash, bundle_opts: bundle_opts, ctx: ctx,
      sourcemap_hidden: sourcemap_hidden} = build_ctx
    File.mkdir_p!(outdir)

    js_files = Rewriter.rewrite_external_imports(js_files, ctx)
    bundle_opts = Keyword.put(bundle_opts, :entry, Path.basename(entry))

    case OXC.bundle(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = BundleResult.extract(bundle_result)
        js_code = Rewriter.inject_external_preamble(js_code, js_files, ctx)

        js_code =
          Rewriter.rewrite_worker_urls(js_code, Rewriter.entry_worker_map(js_files, ctx), name)

        js_code =
          Volt.PluginRunner.render_chunk(ctx.plugins, js_code, %{name: name, type: :entry})

        js_filename = Writer.hashed_name(name, js_code, ".js", hash)
        Writer.write_js(outdir, js_filename, js_code, js_sourcemap, hidden: sourcemap_hidden)

        css_result = Writer.write_css(css_parts, outdir, name, hash, bundle_opts)
        manifest = Writer.build_manifest(name, js_filename, css_result)
        Writer.write_manifest(outdir, manifest)

        {:ok,
         %{
           js: %{path: Path.join(outdir, js_filename), size: byte_size(js_code)},
           css: css_result,
           manifest: manifest
         }}

      {:error, _} = error ->
        error
    end
  end

  @doc "Bundle modules into separate chunks based on the chunk graph."
  def build_chunks(entry, name, {js_files, css_parts}, {modules, dep_map}, build_ctx) do
    %{outdir: outdir, hash: hash, bundle_opts: bundle_opts, ctx: ctx,
      sourcemap_hidden: sourcemap_hidden} = build_ctx
    File.mkdir_p!(outdir)

    graph = Volt.ChunkGraph.build(entry, modules, dep_map)
    js_map = Map.new(js_files)

    chunk_bundles = build_chunk_bundles(graph.chunks, js_map, bundle_opts, ctx)

    chunk_url_map =
      Map.new(chunk_bundles, fn {chunk_id, {_code, _sourcemap}} ->
        chunk = graph.chunks[chunk_id]
        chunk_name = if chunk.type == :entry, do: name, else: "#{name}-#{chunk_id}"
        {chunk_id, Writer.hashed_name(chunk_name, elem(chunk_bundles[chunk_id], 0), ".js", hash)}
      end)

    js_results =
      Enum.map(chunk_bundles, fn {chunk_id, {code, sourcemap}} ->
        chunk = graph.chunks[chunk_id]
        chunk_js = select_chunk_files(chunk.modules, js_map)
        code = Rewriter.inject_external_preamble(code, chunk_js, ctx)
        code = Rewriter.rewrite_dynamic_imports(code, graph.module_to_chunk, chunk_url_map)

        code =
          Rewriter.rewrite_worker_urls(code, Rewriter.entry_worker_map(chunk_js, ctx), chunk_id)

        code =
          Volt.PluginRunner.render_chunk(ctx.plugins, code, %{name: chunk_id, type: chunk.type})

        filename =
          Writer.hashed_name(
            if(chunk.type == :entry, do: name, else: "#{name}-#{chunk_id}"),
            code,
            ".js",
            hash
          )

        Writer.write_js(outdir, filename, code, sourcemap, hidden: sourcemap_hidden)

        %{
          path: Path.join(outdir, filename),
          size: byte_size(code),
          chunk_id: chunk_id,
          type: chunk.type
        }
      end)

    entry_js = Enum.find(js_results, &(&1.type == :entry)) || hd(js_results)
    css_result = Writer.write_css(css_parts, outdir, name, hash, bundle_opts)

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

    Writer.write_manifest(outdir, manifest)

    {:ok,
     %{
       js: entry_js,
       css: css_result,
       manifest: manifest,
       chunks: js_results
     }}
  end

  defp build_chunk_bundles(chunks, js_map, bundle_opts, ctx) do
    Enum.reduce(chunks, %{}, fn {chunk_id, chunk}, acc ->
      chunk_js = select_chunk_files(chunk.modules, js_map)

      if chunk_js == [] do
        acc
      else
        chunk_js = Rewriter.rewrite_external_imports(chunk_js, ctx)
        bundle_opts = Keyword.put(bundle_opts, :entry, chunk_entry_label(chunk_js))

        case OXC.bundle(chunk_js, bundle_opts) do
          {:ok, result} ->
            {code, sourcemap} = BundleResult.extract(result)
            Map.put(acc, chunk_id, {code, sourcemap})

          {:error, _} ->
            acc
        end
      end
    end)
  end

  defp chunk_entry_label([{label, _code} | _]), do: label

  defp select_chunk_files(module_paths, js_map) do
    module_paths
    |> Enum.map(fn mod_path ->
      label = Path.basename(mod_path)
      {label, Map.get(js_map, label, "")}
    end)
    |> Enum.reject(fn {_, code} -> code == "" end)
  end
end
