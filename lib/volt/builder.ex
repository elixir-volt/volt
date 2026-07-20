defmodule Volt.Builder do
  require Logger

  @moduledoc """
  Production build — resolve dependencies, split chunks, bundle, and write assets.

  Walks the dependency graph from entry files, compiles source through
  `Volt.Pipeline`, expands Vite-compatible features such as `import.meta.glob()`
  and dynamic import variables, bundles chunks with `OXC.bundle/2`, rewrites CSS
  and JavaScript asset references, and writes content-hashed output files with a
  manifest.
  """

  alias Volt.Builder.{Bundle, Collector, Naming, Output}
  alias Volt.Paths

  @css_exts Volt.JS.Extensions.css()
  @css_import_noop "data:text/javascript,export{}"
  @dynamic_css_import_noop "Promise.resolve({ default: undefined })"

  @doc """
  Build production assets from one or more entry files.

  ## Options

    * `:entry` — entry file path, plugin-resolved virtual entry specifier, or list of entries (required)
    * `:outdir` — output directory (default: `"priv/static/assets"`)
    * `:public_dir` — optional Vite-style public directory copied to the static root as-is
    * `:target` — JS target (e.g. `:es2020`)
    * `:minify` — minify output (default: `true`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:define` — compile-time replacements
    * `:node_modules` — path to node_modules (default: auto-detect)
    * `:resolve_dirs` — additional directories to resolve bare specifiers (e.g. `["deps"]`)
    * `:package_scopes` — source-root/package-directory pairs. Bare imports originating
      below a source root resolve from its package directory before global package roots.
    * `:name` — output base name (default: derived from entry filename)
    * `:aliases` — import alias map (e.g. `%{"@" => "assets/src"}`)
    * `:plugins` — list of `Volt.Plugin` modules. Plugin `resolve/2` and `load/1` hooks can provide virtual modules and virtual build entries.
    * `:mode` — build mode for env variables (default: `"production"`)
    * `:env_prefix` — env variable prefix or prefixes exposed to client code (default: `"VOLT_"`)
    * `:asset_url_prefix` — public URL prefix for emitted asset references (default: `"/assets"`)
    * `:code_splitting` — split dynamic imports and multi-entry ESM shared modules into chunks (default: `true`)
    * `:tree_shaking` — remove unused exports (default: `true`)
    * `:chunks` — manual chunk definitions, map of chunk name to list of patterns:

          chunks: %{"vendor" => ["vue", "vue-router"], "ui" => ["assets/src/components"]}
    * `:external` — specifiers to exclude from the bundle and access as globals.
      Accepts a list (global name auto-derived) or a map of `specifier => global_name`:

          external: ["vue", "phoenix"]
          external: %{"vue" => "Vue", "phoenix" => "Phoenix"}
  """
  @spec build(keyword()) :: {:ok, Volt.Builder.Result.t()} | {:error, term()}
  def build(opts) do
    plugins = Keyword.get(opts, :plugins, [])

    entries =
      opts |> Keyword.fetch!(:entry) |> List.wrap() |> Enum.map(&resolve_entry(&1, plugins))

    public_dir = opts |> Keyword.get(:public_dir, false) |> Volt.PublicDir.resolve()
    name = Keyword.get(opts, :name)
    {ctx, build_ctx} = build_contexts(entries, opts)

    Volt.PublicDir.copy(public_dir, Path.dirname(build_ctx.outdir))

    expanded_entries = entries |> Enum.flat_map(&expand_entry(&1, name)) |> unique_entry_names()

    results =
      if shared_entries?(expanded_entries, build_ctx, name) do
        [build_shared_entries(expanded_entries, ctx, build_ctx)]
      else
        build_isolated_entries(expanded_entries, ctx, build_ctx)
      end

    with {:ok, result} <- finalize_build_results(results) do
      Volt.Builder.Writer.write_manifest(build_ctx.outdir, result.manifest)
      {:ok, result}
    end
  end

  defp shared_entries?(entries, build_ctx, name) do
    Keyword.get(build_ctx.bundle_opts, :format) == :esm and build_ctx.code_splitting and
      is_nil(name) and
      build_ctx.chunks == %{} and length(entries) > 1 and
      Enum.all?(entries, fn {_entry_path, type, _entry_name} -> type == :script end)
  end

  defp build_shared_entries(entries, ctx, build_ctx) do
    with {:ok, collected} <- collect_shared_entries(entries, ctx),
         false <- label_collision?(collected.path_labels),
         {:ok, worker_results} <- build_worker_results(collected.workers, ctx, build_ctx),
         {:ok, compiled} <- compile_all(collected.modules, build_ctx.target, ctx) do
      compiled =
        rewrite_nonlocal_labels(compiled, collected.specifier_labels, collected.path_labels)

      output_ctx = %Volt.Builder.OutputContext{
        plugins: ctx.plugins,
        external_set: ctx.external,
        external_globals: ctx.external_globals,
        workers: collected.workers,
        worker_results: worker_results
      }

      out = %Volt.Builder.BuildContext{
        outdir: build_ctx.outdir,
        hash: build_ctx.hash,
        bundle_opts: build_ctx.bundle_opts,
        sourcemap_hidden: build_ctx.sourcemap_hidden,
        chunks: build_ctx.chunks,
        ctx: output_ctx,
        asset_url_prefix: build_ctx.asset_url_prefix
      }

      case Output.build_shared_entries(
             entries,
             compiled,
             collected.modules,
             collected.path_labels,
             out
           ) do
        {:error, :shared_entry_module_ids_unavailable} ->
          build_isolated_entries(entries, ctx, build_ctx) |> finalize_build_results()

        result ->
          result
      end
    else
      true -> build_isolated_entries(entries, ctx, build_ctx) |> finalize_build_results()
      {:error, _} = error -> error
    end
  end

  defp build_isolated_entries(entries, ctx, build_ctx) do
    Enum.map(entries, fn {entry_path, entry_type, entry_name} ->
      build_entry(entry_path, entry_type, entry_name, ctx, build_ctx)
    end)
  end

  defp collect_shared_entries(entries, ctx) do
    Enum.reduce_while(entries, {:ok, empty_shared_collection()}, fn {entry, :script, _name},
                                                                    {:ok, acc} ->
      case Collector.collect(entry, ctx) do
        {:ok, modules, _dep_map, workers, specifier_labels, path_labels} ->
          {:cont,
           {:ok,
            %{
              modules: merge_modules(acc.modules, modules),
              workers: merge_nested_maps(acc.workers, workers),
              specifier_labels: Map.merge(acc.specifier_labels, specifier_labels),
              path_labels: Map.merge(acc.path_labels, path_labels)
            }}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp empty_shared_collection do
    %{modules: [], workers: %{}, specifier_labels: %{}, path_labels: %{}}
  end

  defp merge_modules(left, right) do
    seen = MapSet.new(left, fn {path, _label, _source} -> path end)
    left ++ Enum.reject(right, fn {path, _label, _source} -> MapSet.member?(seen, path) end)
  end

  defp merge_nested_maps(left, right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      Map.merge(left_value, right_value)
    end)
  end

  defp label_collision?(path_labels) do
    path_labels
    |> Map.values()
    |> Enum.frequencies()
    |> Enum.any?(fn {_label, count} -> count > 1 end)
  end

  @doc """
  Bundle one JavaScript entry with Volt's normal build graph and return it in memory.

  `bundle/1` accepts the same graph, compiler, and bundler options as `build/1`,
  including `:plugins`, `:aliases`, `:node_modules`, `:resolve_dirs`, `:loaders`,
  `:define`, `:target`, and `:external`. It does not write a manifest or output
  JavaScript files, and it always returns a single entry bundle.

  This API is intended for tools that need executable JavaScript from Volt's
  production resolver/compiler pipeline without production file output, such as
  test runners.
  """
  @spec bundle(keyword()) :: {:ok, Bundle.t()} | {:error, term()}
  def bundle(opts) do
    plugins = Keyword.get(opts, :plugins, [])
    entry = opts |> Keyword.fetch!(:entry) |> resolve_entry(plugins)
    name = Keyword.get(opts, :name)

    case expand_entry(entry, name) do
      [{entry_path, :script, entry_name}] ->
        {ctx, build_ctx} = build_contexts([entry_path], Keyword.put_new(opts, :outdir, nil))
        bundle_entry(entry_path, entry_name, ctx, %{build_ctx | code_splitting: false})

      [{_entry_path, type, _entry_name}] ->
        {:error, {:unsupported_bundle_entry, type}}

      entries ->
        {:error, {:expected_single_bundle_entry, entries}}
    end
  end

  defp bundle_entry(entry, _name, ctx, build_ctx) do
    with {:ok, modules, _dep_map, workers, specifier_labels, path_labels} <-
           Collector.collect(entry, ctx),
         :ok <- ensure_in_memory_workers_supported(workers),
         {:ok, compiled} <- compile_all(modules, build_ctx.target, ctx) do
      compiled = rewrite_nonlocal_labels(compiled, specifier_labels, path_labels)

      output_ctx = %Volt.Builder.OutputContext{
        plugins: ctx.plugins,
        external_set: ctx.external,
        external_globals: ctx.external_globals,
        workers: workers,
        worker_results: %{}
      }

      out = %Volt.Builder.BuildContext{
        outdir: build_ctx.outdir,
        hash: false,
        bundle_opts: build_ctx.bundle_opts,
        sourcemap_hidden: false,
        chunks: %{},
        ctx: output_ctx,
        asset_url_prefix: build_ctx.asset_url_prefix
      }

      files =
        Enum.flat_map(modules, fn {path, _label, _source} -> List.wrap(source_file(path)) end)

      Output.bundle_single(entry, compiled, Enum.uniq(files), out)
    end
  end

  defp ensure_in_memory_workers_supported(workers) when map_size(workers) == 0, do: :ok

  defp ensure_in_memory_workers_supported(workers),
    do: {:error, {:unsupported_bundle_workers, workers}}

  defp source_file(module_id) do
    {path, _query} = Volt.URL.split_query(module_id)

    cond do
      File.regular?(path) ->
        path

      match?({:ok, _id}, Volt.Plugin.EmbeddedModule.parse_id(path)) ->
        {:ok, id} = Volt.Plugin.EmbeddedModule.parse_id(path)
        if File.regular?(id.parent), do: id.parent

      true ->
        nil
    end
  end

  defp build_entry(entry, :script, name, ctx, build_ctx) do
    %{
      outdir: outdir,
      target: target,
      hash: hash,
      bundle_opts: bundle_opts,
      code_splitting: code_splitting
    } = build_ctx

    with {:ok, modules, dep_map, workers, specifier_labels, path_labels} <-
           Collector.collect(entry, ctx),
         {:ok, compiled} <- compile_all(modules, target, ctx),
         {:ok, worker_results} <- build_worker_results(workers, ctx, build_ctx) do
      compiled = rewrite_nonlocal_labels(compiled, specifier_labels, path_labels)

      output_ctx = %Volt.Builder.OutputContext{
        plugins: ctx.plugins,
        external_set: ctx.external,
        external_globals: ctx.external_globals,
        workers: workers,
        worker_results: worker_results
      }

      out = %Volt.Builder.BuildContext{
        outdir: outdir,
        hash: hash,
        bundle_opts: bundle_opts,
        sourcemap_hidden: build_ctx.sourcemap_hidden,
        chunks: build_ctx.chunks,
        ctx: output_ctx,
        asset_url_prefix: build_ctx.asset_url_prefix
      }

      use_chunks =
        code_splitting and
          (has_dynamic_imports?(dep_map) or build_ctx.chunks != %{})

      if use_chunks do
        Output.build_chunks(entry, name, compiled, {modules, dep_map}, out)
      else
        Output.build_single(entry, name, compiled, out)
      end
    end
  end

  defp build_entry(entry, :style, name, _ctx, build_ctx) do
    %{outdir: outdir, hash: hash, bundle_opts: bundle_opts, asset_url_prefix: asset_url_prefix} =
      build_ctx

    with {:ok, source} <- File.read(entry),
         {:ok, compiled} <-
           Volt.Pipeline.compile(entry, source,
             minify: bundle_opts[:minify] || false,
             mode: :production
           ) do
      Volt.Builder.Writer.build_style_entry(
        name,
        compiled.code,
        outdir,
        hash,
        entry,
        Keyword.put(bundle_opts, :asset_url_prefix, asset_url_prefix)
      )
    end
  end

  defp resolve_entry(entry, plugins) do
    entry = to_string(entry)

    case Volt.PluginRunner.resolve(plugins, entry, nil) do
      {:ok, resolved} -> resolved
      :skip -> entry
      nil -> Path.expand(entry)
    end
  end

  defp entry_base(entry) do
    if Path.type(entry) == :absolute do
      Path.dirname(entry)
    else
      File.cwd!()
    end
  end

  defp build_contexts(entries, opts) do
    outdir =
      case Keyword.get(opts, :outdir, Paths.static()) do
        nil -> nil
        outdir -> Path.expand(outdir)
      end

    target = opts |> Keyword.get(:target, "") |> to_string()
    minify = Keyword.get(opts, :minify, true)
    sourcemap_opt = Keyword.get(opts, :sourcemap, true)
    sourcemap = sourcemap_opt != false
    define = Keyword.get(opts, :define, %{})
    mode = Keyword.get(opts, :mode, "production")
    env_prefix = Keyword.get(opts, :env_prefix, "VOLT_")
    asset_url_prefix = Keyword.get(opts, :asset_url_prefix, Paths.prefix())
    aliases = Keyword.get(opts, :aliases, %{})
    code_splitting = Keyword.get(opts, :code_splitting, true)
    tree_shaking = Keyword.get(opts, :tree_shaking, true)
    chunks = Keyword.get(opts, :chunks, %{})
    format = Keyword.get(opts, :format, :iife)
    external_raw = Keyword.get(opts, :external, [])
    {external_set, external_globals} = normalize_external(external_raw)
    first_entry = hd(entries)

    node_modules =
      Keyword.get(opts, :node_modules) ||
        NPM.Resolution.PackageResolver.find_node_modules(entry_base(first_entry))

    resolve_dirs = Keyword.get(opts, :resolve_dirs, []) |> Enum.map(&Path.expand/1)
    package_scopes = opts |> Keyword.get(:package_scopes, []) |> normalize_package_scopes()
    loaders = Keyword.get(opts, :loaders, %{})
    module_types = Keyword.get(opts, :module_types, %{})
    import_source = opts |> Keyword.get(:import_source) |> to_string_or_nil()
    hash = Keyword.get(opts, :hash, true)
    asset_root = Keyword.get(opts, :root, Paths.assets())

    env_define = Volt.Env.define(mode: mode, root: File.cwd!(), env_prefix: env_prefix)
    plugin_define = Volt.PluginRunner.define(Keyword.get(opts, :plugins, []), mode)

    all_define =
      env_define
      |> Map.merge(plugin_define)
      |> Map.merge(define)

    ctx = %Volt.Builder.Context{
      node_modules: node_modules,
      resolve_dirs: resolve_dirs,
      package_scopes: package_scopes,
      aliases: aliases,
      plugins: Keyword.get(opts, :plugins, []),
      external: external_set,
      external_globals: external_globals,
      loaders: loaders,
      module_types: module_types,
      import_source: import_source,
      target: target,
      define: all_define,
      asset_url_prefix: asset_url_prefix,
      asset_outdir: outdir,
      asset_root: asset_root
    }

    bundle_opts =
      [
        minify: minify,
        sourcemap: sourcemap,
        target: target,
        define: all_define,
        format: format,
        treeshake: tree_shaking,
        root: asset_root,
        node_modules: node_modules,
        resolve_dirs: resolve_dirs
      ] ++ if(module_types != %{}, do: [module_types: module_types], else: [])

    build_ctx = %Volt.Builder.BuildContext{
      outdir: outdir,
      target: target,
      hash: hash,
      bundle_opts: bundle_opts,
      asset_url_prefix: asset_url_prefix,
      code_splitting: code_splitting,
      sourcemap_hidden: sourcemap_opt == :hidden,
      chunks: chunks
    }

    {ctx, build_ctx}
  end

  defp has_dynamic_imports?(dep_map) do
    Enum.any?(dep_map, fn {_, %{dynamic: dyn}} -> dyn != [] end)
  end

  defp build_worker_results(workers, ctx, build_ctx) do
    worker_specs =
      workers
      |> Enum.flat_map(fn {_importer, spec_map} -> Map.to_list(spec_map) end)
      |> Enum.uniq_by(fn {_specifier, resolved_path} -> resolved_path end)

    duplicate_worker_basenames = duplicate_worker_basenames(worker_specs)

    Enum.reduce_while(worker_specs, {:ok, %{}}, fn {_specifier, resolved_path}, {:ok, acc} ->
      if Map.has_key?(acc, resolved_path) do
        {:cont, {:ok, acc}}
      else
        worker_name = worker_output_name(resolved_path, duplicate_worker_basenames)

        case build_entry(
               resolved_path,
               :script,
               worker_name,
               ctx,
               %{build_ctx | code_splitting: false}
             ) do
          {:ok, %{js: %{path: path}}} ->
            {:cont, {:ok, Map.put(acc, resolved_path, Path.basename(path))}}

          {:error, reason} ->
            {:halt, {:error, {:worker_build_failed, resolved_path, reason}}}
        end
      end
    end)
  end

  defp duplicate_worker_basenames(worker_specs) do
    worker_specs
    |> Enum.map(fn {_specifier, resolved_path} ->
      resolved_path |> Path.basename() |> Path.rootname()
    end)
    |> Enum.frequencies()
    |> Map.filter(fn {_name, count} -> count > 1 end)
    |> MapSet.new(fn {name, _count} -> name end)
  end

  defp worker_output_name(resolved_path, duplicate_basenames) do
    name = resolved_path |> Path.basename() |> Path.rootname()

    if MapSet.member?(duplicate_basenames, name) do
      "#{name}-#{Volt.Format.content_hash(resolved_path)}"
    else
      name
    end
  end

  # ── Module compilation ──────────────────────────────────────────────

  defp compile_all(modules, _target, ctx) do
    with {:ok, compiled} <- compile_modules(modules, ctx) do
      merge_compiled(compiled)
    end
  end

  defp compile_modules(modules, ctx) do
    Enum.reduce_while(modules, {:ok, []}, fn {path, label, source}, {:ok, acc} ->
      case compile_module(path, label, source, ctx) do
        {:ok, js, css, assets} -> {:cont, {:ok, [{label, js, css_part(path, css), assets} | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp css_part(_path, nil), do: nil
  defp css_part(path, css), do: {css_source_path(path), css}

  defp css_source_path(path) do
    case Volt.Plugin.EmbeddedModule.parse_id(path) do
      {:ok, %Volt.Plugin.EmbeddedModule.ID{parent: parent, type: :style, index: index}} ->
        parent <> ".style#{index}.css"

      _ ->
        path
    end
  end

  defp merge_compiled(compiled) do
    {js_files, css_parts, assets} =
      compiled
      |> Enum.reverse()
      |> Enum.reduce({[], [], []}, fn {label, js, css, assets}, {js_acc, css_acc, asset_acc} ->
        {[{label, js} | js_acc], if(css, do: [css | css_acc], else: css_acc),
         [assets | asset_acc]}
      end)

    {:ok,
     {Enum.reverse(js_files), Enum.reverse(css_parts), assets |> List.flatten() |> Enum.uniq()}}
  end

  defp compile_module(module_id, _label, source, ctx) do
    {path, query} = Volt.URL.split_query(module_id)

    cond do
      embedded_style?(module_id, ctx.plugins) ->
        compile_css_import(module_id, source, ctx)

      asset_module_query?(query) ->
        compile_asset_module(path, query, ctx)

      Path.extname(path) in @css_exts and not Volt.CSS.Modules.css_module?(path) ->
        compile_css_import(path, source, ctx)

      Volt.Assets.asset?(path) ->
        compile_asset_module(path, query, ctx)

      true ->
        case Volt.Builder.Compiler.compile(module_id, source, ctx) do
          {:ok, %{code: code, css: css}} -> {:ok, code, css, []}
          {:error, _} = error -> error
        end
    end
  end

  defp asset_module_query?(query) do
    query
    |> Volt.URL.decode_query()
    |> Map.keys()
    |> Enum.any?(&(&1 in ["raw", "url", "inline", "no-inline"]))
  end

  defp compile_asset_module(path, query, ctx) do
    query_params = Volt.URL.decode_query(query)

    asset_opts = [
      raw: Map.has_key?(query_params, "raw"),
      url: Map.has_key?(query_params, "url"),
      inline: Map.has_key?(query_params, "inline"),
      no_inline: Map.has_key?(query_params, "no-inline"),
      prefix: ctx.asset_url_prefix,
      outdir: ctx.asset_outdir,
      root: ctx.asset_root
    ]

    case Volt.Assets.emit_js_module(path, asset_opts) do
      {:ok, %{code: js, assets: assets}} -> {:ok, js, nil, assets}
      {:error, _} = error -> error
    end
  end

  defp embedded_style?(module_id, plugins) do
    match?({:ok, %{type: :style}, _parent}, Volt.PluginRunner.embedded_module(plugins, module_id))
  end

  defp compile_css_import(path, source, ctx) do
    case Volt.Builder.Compiler.compile(path, source, ctx) do
      {:ok, %{code: css}} -> {:ok, "export default undefined;", css, []}
      {:error, _} = error -> error
    end
  end

  defp rewrite_nonlocal_labels({js_files, css_parts, assets}, specifier_labels, path_labels) do
    label_to_path = Map.new(path_labels, fn {path, label} -> {label, path} end)

    global_specifier_map =
      specifier_labels
      |> Map.values()
      |> Enum.reduce(%{}, &Map.merge(&2, &1))
      |> Map.reject(fn {spec, _} ->
        String.starts_with?(spec, "./") or String.starts_with?(spec, "../")
      end)

    js_files =
      Enum.map(js_files, fn {label, code} ->
        file_path = label_to_path[label]

        if is_nil(file_path) do
          Logger.warning(
            "[Volt] No path mapping for label #{inspect(label)}, imports will not be rewritten"
          )
        end

        file_specifier_map = Map.get(specifier_labels, file_path, %{})

        rewrite_map =
          Map.new(file_specifier_map, fn {spec, lbl} ->
            {spec, relative_label(label, lbl)}
          end)

        new_code = rewrite_imports_to_labels(code, rewrite_map, label, global_specifier_map)
        {label, new_code}
      end)

    {js_files, css_parts, assets}
  end

  defp relative_label(from_label, to_label) do
    from_dir = Path.dirname(from_label)
    Path.relative_to(to_label, from_dir)
  end

  defp rewrite_imports_to_labels(code, label_map, from_label, global_map) do
    case compact_import_label_patches(code, label_map, from_label, global_map) do
      {:ok, []} -> code
      {:ok, patches} -> OXC.patch_string(code, patches)
      :fallback -> rewrite_imports_to_labels_from_ast(code, label_map, from_label, global_map)
    end
  end

  defp compact_import_label_patches(code, label_map, from_label, global_map) do
    with {:ok, imports} <- OXC.select(code, "module.js", :import_sources),
         {:ok, []} <- OXC.select(code, "module.js", :require_calls),
         false <- dynamic_css_import?(imports) do
      patches =
        Enum.reduce(imports, [], fn %{specifier: specifier, start: start, end: end_offset}, acc ->
          case rewrite_specifier(specifier, label_map, from_label, global_map) do
            {:rewrite, replacement} ->
              [%{start: start, end: end_offset, change: Jason.encode!(replacement)} | acc]

            :keep ->
              acc
          end
        end)

      {:ok, patches}
    else
      _unsupported_or_invalid -> :fallback
    end
  end

  defp dynamic_css_import?(imports) do
    Enum.any?(imports, fn import ->
      import.type == :dynamic and Path.extname(import.specifier) in @css_exts
    end)
  end

  defp rewrite_imports_to_labels_from_ast(code, label_map, from_label, global_map) do
    case OXC.parse(code, "module.js") do
      {:ok, ast} ->
        patches = collect_import_label_patches(ast, label_map, from_label, global_map)
        if patches == [], do: code, else: Volt.JS.Patch.apply(code, patches)

      {:error, _} ->
        code
    end
  end

  defp collect_import_label_patches(ast, label_map, from_label, global_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: type, source: source} = node, patches
        when type in [:import_declaration, :export_all_declaration, :export_named_declaration] ->
          {node, maybe_rewrite_import_source(source, patches, label_map, from_label, global_map)}

        %{
          type: :import_expression,
          source: %{type: :literal, value: spec},
          start: start,
          end: finish
        } = node,
        patches
        when is_binary(spec) and is_integer(start) and is_integer(finish) ->
          rewrite_import_expression(
            node,
            patches,
            spec,
            start,
            finish,
            label_map,
            from_label,
            global_map
          )

        %{type: :import_expression, source: source} = node, patches ->
          {node, maybe_rewrite_import_source(source, patches, label_map, from_label, global_map)}

        node, patches ->
          case Volt.JS.AST.call_arguments(node, "require") do
            {:ok, [source | _]} ->
              {node,
               maybe_rewrite_import_source(source, patches, label_map, from_label, global_map)}

            _ ->
              {node, patches}
          end
      end)

    patches
  end

  defp rewrite_import_expression(
         node,
         patches,
         spec,
         start,
         finish,
         label_map,
         from_label,
         global_map
       ) do
    if Path.extname(spec) in @css_exts do
      {node, [Volt.JS.Patch.new(start, finish, @dynamic_css_import_noop) | patches]}
    else
      {node,
       maybe_rewrite_specifier(spec, node.source, patches, label_map, from_label, global_map)}
    end
  end

  defp maybe_rewrite_import_source(source, patches, label_map, from_label, global_map) do
    case Volt.JS.AST.string_literal_span(source) do
      {:ok, specifier, _start_pos, _end_pos} ->
        maybe_rewrite_specifier(specifier, source, patches, label_map, from_label, global_map)

      nil ->
        patches
    end
  end

  defp maybe_rewrite_specifier(specifier, source, patches, label_map, from_label, global_map) do
    case rewrite_specifier(specifier, label_map, from_label, global_map) do
      {:rewrite, replacement} ->
        [
          Volt.JS.Patch.replace_selector(source, Volt.JS.AST.string_literal(replacement))
          | patches
        ]

      :keep ->
        patches
    end
  end

  defp rewrite_specifier(specifier, label_map, from_label, global_map) do
    if Path.extname(specifier) in @css_exts and not Volt.CSS.Modules.css_module?(specifier) do
      {:rewrite, @css_import_noop}
    else
      case Map.fetch(label_map, specifier) do
        {:ok, new_label} ->
          {:rewrite, "./" <> new_label}

        :error ->
          case Map.fetch(global_map, specifier) do
            {:ok, lbl} when not is_nil(from_label) ->
              {:rewrite, "./" <> relative_label(from_label, lbl)}

            _ ->
              :keep
          end
      end
    end
  end

  defp expand_entry(entry, override_name) do
    if Volt.HTMLEntry.html?(entry) do
      {:ok, %{scripts: scripts, styles: styles}} = Volt.HTMLEntry.extract(entry)

      Enum.map(
        scripts,
        &{&1, :script, &1 |> Path.basename() |> Path.rootname() |> Naming.file_path()}
      ) ++
        Enum.map(
          styles,
          &{&1, :style, &1 |> Path.basename() |> Path.rootname() |> Naming.file_path()}
        )
    else
      type = if Path.extname(entry) in @css_exts, do: :style, else: :script
      entry_name = Naming.file_path(override_name || entry |> Path.basename() |> Path.rootname())
      [{entry, type, entry_name}]
    end
  end

  defp unique_entry_names(entries) do
    {entries, _used_names} =
      Enum.map_reduce(entries, MapSet.new(), fn {entry, type, name}, used_names ->
        unique_name = unique_entry_name(name, entry, used_names)
        {{entry, type, unique_name}, MapSet.put(used_names, unique_name)}
      end)

    entries
  end

  defp unique_entry_name(name, entry, used_names) do
    if MapSet.member?(used_names, name) do
      digest = :crypto.hash(:sha256, entry) |> Base.encode16(case: :lower) |> binary_part(0, 10)
      candidate = "#{name}-#{digest}"

      if MapSet.member?(used_names, candidate) do
        unique_entry_name(candidate, entry, used_names)
      else
        candidate
      end
    else
      name
    end
  end

  defp normalize_package_scopes(scopes) when is_map(scopes) or is_list(scopes) do
    scopes
    |> Enum.map(fn {source_root, package_dir} ->
      {Path.expand(source_root), Path.expand(package_dir)}
    end)
    |> Enum.sort_by(fn {source_root, _package_dir} -> -byte_size(source_root) end)
  end

  defp normalize_external(externals) when is_map(externals) do
    set = externals |> Map.keys() |> MapSet.new()
    {set, externals}
  end

  defp normalize_external(externals) when is_list(externals) do
    set = MapSet.new(externals)
    globals = Map.new(externals, &{&1, derive_global_name(&1)})
    {set, globals}
  end

  @doc false
  def derive_global_name(specifier) do
    specifier
    |> String.replace(~r"^@\w+/", "")
    |> String.split(~r"[-_/]")
    |> Enum.map_join(&String.capitalize/1)
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)

  defp finalize_build_results(results) do
    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {[{:ok, single}], []} -> {:ok, single}
      {successes, []} when successes != [] -> {:ok, merge_build_results(successes)}
      {_, [first_error | _]} -> first_error
    end
  end

  defp merge_build_results(results) do
    Enum.reduce(results, %Volt.Builder.Result{}, fn {:ok, result}, acc ->
      %Volt.Builder.Result{
        js: [result.js | acc.js],
        css: result.css || acc.css,
        manifest: Map.merge(acc.manifest, result.manifest)
      }
    end)
  end
end
