defmodule Volt.Builder.Output do
  @moduledoc "Builds final production output files from compiled module graphs."

  alias Volt.Builder.{Writer, Rewriter}

  @doc "Bundle modules into a single in-memory JS bundle."
  def bundle_single(entry, {js_files, css_parts, assets}, files, build_ctx) do
    %{
      outdir: outdir,
      bundle_opts: bundle_opts,
      ctx: ctx,
      asset_url_prefix: asset_url_prefix
    } = build_ctx

    js_files = Rewriter.rewrite_external_imports(js_files, ctx)
    bundle_opts = Keyword.put(bundle_opts, :entry, Path.basename(entry))

    case bundle_js_files(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle_result(bundle_result)
        js_code = Rewriter.inject_external_preamble(js_code, js_files, ctx)

        js_code =
          Rewriter.rewrite_worker_urls(
            js_code,
            Rewriter.all_worker_map(ctx),
            Path.rootname(Path.basename(entry))
          )

        js_code =
          Volt.PluginRunner.render_chunk(ctx.plugins, js_code, %{
            name: Path.rootname(Path.basename(entry)),
            type: :entry
          })

        css_opts = Keyword.put(bundle_opts, :asset_url_prefix, asset_url_prefix)

        with {:ok, css_result} <- bundle_css(css_parts, outdir, css_opts) do
          {:ok,
           %Volt.Builder.Bundle{
             entry: entry,
             code: js_code,
             sourcemap: js_sourcemap,
             files: Enum.sort(files),
             css: css_code(css_result),
             assets: Enum.uniq(assets ++ css_assets(css_result))
           }}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Bundle modules into a single JS file and write output."
  def build_single(entry, name, {js_files, css_parts, assets}, build_ctx) do
    %{
      outdir: outdir,
      hash: hash,
      bundle_opts: bundle_opts,
      ctx: ctx,
      sourcemap_hidden: sourcemap_hidden,
      asset_url_prefix: asset_url_prefix
    } = build_ctx

    File.mkdir_p!(outdir)

    js_files = Rewriter.rewrite_external_imports(js_files, ctx)
    bundle_opts = Keyword.put(bundle_opts, :entry, Path.basename(entry))

    case bundle_js_files(js_files, bundle_opts) do
      {:ok, bundle_result} ->
        {js_code, js_sourcemap} = extract_bundle_result(bundle_result)
        js_code = Rewriter.inject_external_preamble(js_code, js_files, ctx)

        js_code =
          Rewriter.rewrite_worker_urls(js_code, Rewriter.all_worker_map(ctx), name)

        js_code =
          Volt.PluginRunner.render_chunk(ctx.plugins, js_code, %{name: name, type: :entry})

        js_filename = Writer.hashed_name(name, js_code, ".js", hash)
        Writer.write_js(outdir, js_filename, js_code, js_sourcemap, hidden: sourcemap_hidden)
        css_opts = Keyword.put(bundle_opts, :asset_url_prefix, asset_url_prefix)

        with {:ok, css_result} <- Writer.write_css(css_parts, outdir, name, hash, css_opts) do
          manifest = Writer.build_manifest(name, js_filename, css_result, assets)

          {:ok,
           %Volt.Builder.Result{
             js: %Volt.Builder.OutputFile{
               path: Path.join(outdir, js_filename),
               size: byte_size(js_code)
             },
             css: css_result,
             manifest: manifest
           }}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Bundle modules into separate chunks based on the chunk graph."
  def build_chunks(entry, name, {js_files, css_parts, assets}, {modules, dep_map}, build_ctx) do
    %{
      outdir: outdir,
      hash: hash,
      bundle_opts: bundle_opts,
      ctx: ctx,
      sourcemap_hidden: sourcemap_hidden,
      chunks: manual_chunks,
      asset_url_prefix: asset_url_prefix
    } = build_ctx

    File.mkdir_p!(outdir)

    graph = Volt.ChunkGraph.build(entry, modules, dep_map, manual_chunks: manual_chunks)
    js_map = Map.new(js_files)
    module_labels = Map.new(modules, fn {path, label, _source} -> {path, label} end)

    with {:ok, chunk_bundles} <-
           build_chunk_bundles(
             graph.chunks,
             js_map,
             module_labels,
             bundle_opts,
             ctx,
             graph,
             dep_map
           ) do
      css_opts = Keyword.put(bundle_opts, :asset_url_prefix, asset_url_prefix)

      with {:ok, css_results} <-
             write_chunk_css(css_parts, graph, outdir, name, hash, css_opts) do
        {chunk_url_map, processed_chunks} =
          finalize_chunk_urls(
            chunk_bundles,
            graph,
            js_map,
            module_labels,
            css_results,
            ctx,
            name,
            hash,
            dep_map
          )

        js_results =
          Enum.map(processed_chunks, fn {chunk_id, {code, sourcemap}} ->
            chunk = graph.chunks[chunk_id]
            filename = chunk_url_map[chunk_id]

            Writer.write_js(outdir, filename, code, sourcemap, hidden: sourcemap_hidden)

            %Volt.Builder.OutputFile{
              path: Path.join(outdir, filename),
              size: byte_size(code),
              chunk_id: chunk_id,
              type: chunk.type
            }
          end)

        entry_js = Enum.find(js_results, &(&1.type == :entry)) || hd(js_results)
        entry_css = css_results[entry_js.chunk_id]

        manifest =
          js_results
          |> Enum.reduce(%{}, fn js, acc ->
            chunk = graph.chunks[js.chunk_id]
            filename = Path.basename(js.path)

            entry =
              filename
              |> chunk_manifest_entry(filename, chunk, chunk_url_map)
              |> add_chunk_css(css_results[js.chunk_id])

            Map.put(acc, filename, entry)
          end)
          |> Map.put(
            "#{name}.js",
            "#{name}.js"
            |> chunk_manifest_entry(
              Path.basename(entry_js.path),
              graph.chunks[entry_js.chunk_id],
              chunk_url_map
            )
            |> add_chunk_css(entry_css)
            |> add_chunk_assets(assets)
          )
          |> Writer.add_asset_entries(assets)
          |> Writer.add_asset_entries(css_assets(css_results))

        {:ok,
         %Volt.Builder.Result{
           js: entry_js,
           css: entry_css,
           manifest: manifest,
           chunks: js_results
         }}
      end
    end
  end

  defp finalize_chunk_urls(
         chunk_bundles,
         graph,
         js_map,
         module_labels,
         css_results,
         ctx,
         name,
         hash,
         dep_map
       ) do
    initial_url_map = chunk_url_map(chunk_bundles, graph.chunks, name, hash)

    do_finalize_chunk_urls(
      chunk_bundles,
      graph,
      js_map,
      module_labels,
      css_results,
      ctx,
      name,
      hash,
      dep_map,
      initial_url_map,
      0
    )
  end

  defp do_finalize_chunk_urls(
         chunk_bundles,
         graph,
         js_map,
         module_labels,
         css_results,
         ctx,
         name,
         hash,
         dep_map,
         url_map,
         iteration
       ) do
    processed =
      process_chunks(
        chunk_bundles,
        graph,
        js_map,
        module_labels,
        css_results,
        ctx,
        url_map,
        dep_map
      )

    next_url_map = chunk_url_map(processed, graph.chunks, name, hash)

    if next_url_map == url_map or iteration >= 5 do
      {next_url_map, processed}
    else
      do_finalize_chunk_urls(
        chunk_bundles,
        graph,
        js_map,
        module_labels,
        css_results,
        ctx,
        name,
        hash,
        dep_map,
        next_url_map,
        iteration + 1
      )
    end
  end

  defp process_chunks(
         chunk_bundles,
         graph,
         js_map,
         module_labels,
         css_results,
         ctx,
         chunk_url_map,
         dep_map
       ) do
    preload_map = dynamic_preload_map(graph.chunks, chunk_url_map, css_results)

    Map.new(chunk_bundles, fn {chunk_id, {code, sourcemap}} ->
      chunk = graph.chunks[chunk_id]
      chunk_js = select_chunk_files(chunk.modules, js_map, module_labels)
      chunk_import_map = chunk_import_map(chunk, graph, module_labels, dep_map)
      code = Rewriter.inject_external_preamble(code, chunk_js, ctx)
      code = Rewriter.rewrite_chunk_imports(code, chunk_import_map, chunk_url_map)
      code = Rewriter.rewrite_dynamic_preloads(code, preload_map)

      code =
        Rewriter.rewrite_worker_urls(
          code,
          Rewriter.worker_map_for_modules(chunk.modules, ctx),
          chunk_id
        )

      code =
        Volt.PluginRunner.render_chunk(ctx.plugins, code, %{
          name: chunk_id,
          type: chunk.type
        })

      {chunk_id, {code, sourcemap}}
    end)
  end

  defp chunk_url_map(chunk_bundles, chunks, name, hash) do
    Map.new(chunk_bundles, fn {chunk_id, {code, _sourcemap}} ->
      chunk = chunks[chunk_id]
      {chunk_id, Writer.hashed_name(chunk_output_name(chunk, name), code, ".js", hash)}
    end)
  end

  defp dynamic_preload_map(chunks, chunk_url_map, css_results) do
    chunks
    |> Enum.flat_map(fn {_chunk_id, chunk} -> chunk.dynamic_imports end)
    |> Enum.uniq()
    |> Map.new(fn chunk_id ->
      {"./#{chunk_url_map[chunk_id]}", preload_deps(chunks[chunk_id], chunk_url_map, css_results)}
    end)
  end

  defp preload_deps(chunk, chunk_url_map, css_results) do
    chunk.imports
    |> Enum.flat_map(fn import_id ->
      chunk_file = chunk_url_map[import_id]
      css_files = css_files(css_results[import_id])
      List.wrap(chunk_file) ++ css_files
    end)
    |> Kernel.++(css_files(css_results[chunk.id]))
    |> Enum.map(&"./#{&1}")
    |> Enum.uniq()
  end

  defp css_files(nil), do: []

  defp css_files(css_result),
    do: [Path.basename(css_result.path) | Writer.asset_files(css_result.assets)]

  defp write_chunk_css(css_parts, graph, outdir, name, hash, css_opts) do
    css_parts
    |> Enum.group_by(fn {path, _css} -> Map.get(graph.module_to_chunk, path, "entry") end)
    |> Enum.reduce_while({:ok, %{}}, fn {chunk_id, parts}, {:ok, acc} ->
      chunk = graph.chunks[chunk_id]

      case Writer.write_css(parts, outdir, chunk_output_name(chunk, name), hash, css_opts) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, css_result} -> {:cont, {:ok, Map.put(acc, chunk_id, css_result)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp chunk_output_name(%{type: :entry}, name), do: name
  defp chunk_output_name(chunk, name), do: "#{name}-#{chunk.id}"

  defp chunk_manifest_entry(src, filename, chunk, chunk_url_map) do
    entry = Volt.Builder.ManifestEntry.js(src, filename, entry: chunk.type == :entry)

    %{
      entry
      | imports: chunk_files(chunk.imports, chunk_url_map),
        dynamicImports: chunk_files(chunk.dynamic_imports, chunk_url_map)
    }
  end

  defp add_chunk_css(entry, nil), do: entry

  defp add_chunk_css(entry, css_result) do
    css_file = Path.basename(css_result.path)

    %{
      entry
      | css: [css_file],
        assets: Enum.uniq([css_file | Writer.asset_files(css_result.assets)])
    }
  end

  defp add_chunk_assets(entry, []), do: entry

  defp add_chunk_assets(entry, assets) do
    %{entry | assets: Enum.uniq(entry.assets ++ Writer.asset_files(assets))}
  end

  defp bundle_css([], _outdir, _bundle_opts), do: {:ok, nil}

  defp bundle_css(css_parts, nil, bundle_opts) do
    with {:ok, %{code: css_code, assets: assets}} <- bundle_css_parts(css_parts, bundle_opts),
         {:ok, css_code} <- Volt.Builder.CSS.compile(css_code, bundle_opts) do
      {:ok, %{code: css_code, assets: assets}}
    end
  end

  defp bundle_css(css_parts, outdir, bundle_opts) do
    with {:ok, %{code: css_code, assets: assets}} <-
           Volt.Builder.CSS.rewrite_parts(css_parts, outdir, bundle_opts),
         {:ok, css_code} <- Volt.Builder.CSS.compile(css_code, bundle_opts) do
      {:ok, %{code: css_code, assets: assets}}
    end
  end

  defp bundle_css_parts(css_parts, bundle_opts) do
    Volt.Builder.CSS.bundle_parts(css_parts, &bundle_css_part(&1, bundle_opts))
  end

  defp bundle_css_part({source_path, css}, bundle_opts) do
    root = Keyword.get(bundle_opts, :root) || File.cwd!()
    prefix = Keyword.get(bundle_opts, :asset_url_prefix, Volt.Paths.prefix())

    with {:ok, css} <- Volt.CSS.Imports.inline(css, source_path, bundle_opts),
         {:ok, css} <- Volt.CSS.AssetURLRewriter.rewrite_dev(css, source_path, root, prefix) do
      {:ok, %{code: css, assets: []}}
    end
  end

  defp bundle_css_part(css, _bundle_opts), do: {:ok, %{code: css, assets: []}}

  defp css_code(nil), do: nil
  defp css_code(%{code: code}), do: code

  defp css_assets(nil), do: []
  defp css_assets(%{assets: assets}) when is_list(assets), do: assets

  defp css_assets(css_results) do
    css_results
    |> Map.values()
    |> Enum.flat_map(& &1.assets)
  end

  defp chunk_files([], _chunk_url_map), do: []

  defp chunk_files(chunk_ids, chunk_url_map) do
    Enum.flat_map(chunk_ids, fn chunk_id -> List.wrap(chunk_url_map[chunk_id]) end)
  end

  defp chunk_import_map(chunk, graph, module_labels, dep_map) do
    chunk.modules
    |> Enum.flat_map(fn importer ->
      module_chunk_imports(importer, chunk.id, graph, module_labels, dep_map)
    end)
    |> Map.new()
  end

  defp module_chunk_imports(importer, current_chunk_id, graph, module_labels, dep_map) do
    importer_label = module_labels[importer]
    deps = Map.get(dep_map, importer, %Volt.Builder.Dependencies{})

    (deps.static ++ deps.dynamic)
    |> Enum.flat_map(fn dep ->
      with chunk_id when is_binary(chunk_id) <- Map.get(graph.module_to_chunk, dep),
           false <- chunk_id == current_chunk_id,
           dep_label when is_binary(dep_label) <- module_labels[dep] do
        [{"./" <> relative_label(importer_label, dep_label), chunk_id}]
      else
        _ -> []
      end
    end)
  end

  defp relative_label(from_label, to_label) do
    from_dir = Path.dirname(from_label)
    Path.relative_to(to_label, from_dir)
  end

  defp build_chunk_bundles(chunks, js_map, module_labels, bundle_opts, ctx, graph, dep_map) do
    Enum.reduce_while(chunks, {:ok, %{}}, fn {chunk_id, chunk}, {:ok, acc} ->
      chunk_js = select_chunk_files(chunk.modules, js_map, module_labels)

      if chunk_js == [] do
        {:cont, {:ok, acc}}
      else
        chunk_js = Rewriter.rewrite_external_imports(chunk_js, ctx)
        {chunk_js, dynamic_import_placeholder} = Rewriter.protect_dynamic_imports(chunk_js)

        external =
          Rewriter.external_chunk_imports(
            chunk_js,
            chunk_import_map(chunk, graph, module_labels, dep_map)
          )

        bundle_opts =
          bundle_opts
          |> Keyword.put(:entry, chunk_entry_label(chunk_js))
          |> put_external_imports(external)

        case bundle_js_files(chunk_js, bundle_opts) do
          {:ok, result} ->
            {code, sourcemap} = extract_bundle_result(result)
            code = Rewriter.restore_dynamic_imports(code, dynamic_import_placeholder)
            {:cont, {:ok, Map.put(acc, chunk_id, {code, sourcemap})}}

          {:error, errors} ->
            {:halt, {:error, {:chunk_bundle_failed, chunk_id, errors}}}
        end
      end
    end)
  end

  defp extract_bundle_result(result) when is_binary(result), do: {result, nil}
  defp extract_bundle_result(%{code: code, sourcemap: sourcemap}), do: {code, sourcemap}

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
