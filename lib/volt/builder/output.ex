defmodule Volt.Builder.Output do
  @moduledoc false

  alias Volt.Builder.{Writer, BundleResult, Rewriter}

  @doc "Bundle modules into a single JS file and write output."
  def build_single(entry, name, {js_files, css_parts}, build_ctx) do
    %{
      outdir: outdir,
      hash: hash,
      bundle_opts: bundle_opts,
      ctx: ctx,
      sourcemap_hidden: sourcemap_hidden
    } = build_ctx

    File.mkdir_p!(outdir)

    js_files = Rewriter.rewrite_external_imports(js_files, ctx)
    bundle_opts = Keyword.put(bundle_opts, :entry, Path.basename(entry))

    case bundle_js_files(js_files, bundle_opts) do
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
    %{
      outdir: outdir,
      hash: hash,
      bundle_opts: bundle_opts,
      ctx: ctx,
      sourcemap_hidden: sourcemap_hidden,
      chunks: manual_chunks
    } = build_ctx

    File.mkdir_p!(outdir)

    graph = Volt.ChunkGraph.build(entry, modules, dep_map, manual_chunks: manual_chunks)
    js_map = Map.new(js_files)
    module_labels = Map.new(modules, fn {path, label, _source} -> {path, label} end)

    with {:ok, chunk_bundles} <-
           build_chunk_bundles(graph.chunks, js_map, module_labels, bundle_opts, ctx, graph) do
      chunk_url_map =
        Map.new(chunk_bundles, fn {chunk_id, {_code, _sourcemap}} ->
          chunk = graph.chunks[chunk_id]
          chunk_name = if chunk.type == :entry, do: name, else: "#{name}-#{chunk_id}"

          {chunk_id,
           Writer.hashed_name(chunk_name, elem(chunk_bundles[chunk_id], 0), ".js", hash)}
        end)

      js_results =
        Enum.map(chunk_bundles, fn {chunk_id, {code, sourcemap}} ->
          chunk = graph.chunks[chunk_id]
          chunk_js = select_chunk_files(chunk.modules, js_map, module_labels)
          code = Rewriter.inject_external_preamble(code, chunk_js, ctx)
          code = Rewriter.rewrite_chunk_imports(code, graph.module_to_chunk, chunk_url_map)

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

      manifest = Writer.add_css_to_manifest(manifest, name, css_result)

      Writer.write_manifest(outdir, manifest)

      {:ok,
       %{
         js: entry_js,
         css: css_result,
         manifest: manifest,
         chunks: js_results
       }}
    end
  end

  defp build_chunk_bundles(chunks, js_map, module_labels, bundle_opts, ctx, graph) do
    Enum.reduce_while(chunks, {:ok, %{}}, fn {chunk_id, chunk}, {:ok, acc} ->
      chunk_js = select_chunk_files(chunk.modules, js_map, module_labels)

      if chunk_js == [] do
        {:cont, {:ok, acc}}
      else
        chunk_js = Rewriter.rewrite_external_imports(chunk_js, ctx)
        {chunk_js, dynamic_import_placeholder} = Rewriter.protect_dynamic_imports(chunk_js)

        external = Rewriter.external_chunk_imports(chunk_js, graph.module_to_chunk, chunk_id)

        bundle_opts =
          bundle_opts
          |> Keyword.put(:entry, chunk_entry_label(chunk_js))
          |> put_external_imports(external)

        case bundle_js_files(chunk_js, bundle_opts) do
          {:ok, result} ->
            {code, sourcemap} = BundleResult.extract(result)
            code = Rewriter.restore_dynamic_imports(code, dynamic_import_placeholder)
            {:cont, {:ok, Map.put(acc, chunk_id, {code, sourcemap})}}

          {:error, errors} ->
            {:halt, {:error, {:chunk_bundle_failed, chunk_id, errors}}}
        end
      end
    end)
  end

  defp bundle_js_files(js_files, bundle_opts) do
    case OXC.bundle(js_files, bundle_opts) do
      {:error, [%{message: "Rolldown did not produce a source map"}]} = error ->
        if Keyword.get(bundle_opts, :sourcemap) do
          OXC.bundle(js_files, Keyword.put(bundle_opts, :sourcemap, false))
        else
          error
        end

      result ->
        result
    end
  end

  defp put_external_imports(bundle_opts, []), do: bundle_opts

  defp put_external_imports(bundle_opts, external) do
    Keyword.update(bundle_opts, :external, external, fn existing ->
      Enum.uniq(List.wrap(existing) ++ external)
    end)
  end

  defp chunk_entry_label([{label, _code} | _]), do: label

  defp select_chunk_files(module_paths, js_map, module_labels) do
    module_paths
    |> Enum.flat_map(fn mod_path ->
      with label when is_binary(label) <- module_labels[mod_path],
           code when is_binary(code) <- js_map[label] do
        [{label, code}]
      else
        _ -> []
      end
    end)
  end
end
