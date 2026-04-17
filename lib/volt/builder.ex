defmodule Volt.Builder do
  require Logger

  @moduledoc """
  Production build — resolve dependencies, split chunks, bundle, and write assets.

  Walks the dependency graph from entry files, splits code at dynamic import
  boundaries, compiles everything through the Pipeline, bundles each chunk
  with `OXC.bundle/2`, and writes content-hashed output files with a manifest.
  """

  alias Volt.Builder.{Collector, Output}

  @type build_result :: %{
          js:
            %{path: String.t(), size: non_neg_integer()}
            | [%{path: String.t(), size: non_neg_integer()}],
          css: %{path: String.t(), size: non_neg_integer()} | nil,
          manifest: %{String.t() => String.t()}
        }

  @doc """
  Build production assets from one or more entry files.

  ## Options

    * `:entry` — entry file path or list of paths (required)
    * `:outdir` — output directory (default: `"priv/static/assets"`)
    * `:target` — JS target (e.g. `:es2020`)
    * `:minify` — minify output (default: `true`)
    * `:sourcemap` — generate source maps (default: `true`)
    * `:define` — compile-time replacements
    * `:node_modules` — path to node_modules (default: auto-detect)
    * `:resolve_dirs` — additional directories to resolve bare specifiers (e.g. `["deps"]`)
    * `:name` — output base name (default: derived from entry filename)
    * `:aliases` — import alias map (e.g. `%{"@" => "assets/src"}`)
    * `:plugins` — list of `Volt.Plugin` modules
    * `:mode` — build mode for env variables (default: `"production"`)
    * `:code_splitting` — split dynamic imports into separate chunks (default: `true`)
    * `:chunks` — manual chunk definitions, map of chunk name to list of patterns:

          chunks: %{"vendor" => ["vue", "vue-router"], "ui" => ["assets/src/components"]}
    * `:external` — specifiers to exclude from the bundle and access as globals.
      Accepts a list (global name auto-derived) or a map of `specifier => global_name`:

          external: ["vue", "phoenix"]
          external: %{"vue" => "Vue", "phoenix" => "Phoenix"}
  """
  @spec build(keyword()) :: {:ok, build_result()} | {:error, term()}
  def build(opts) do
    entries = opts |> Keyword.fetch!(:entry) |> List.wrap() |> Enum.map(&Path.expand/1)
    outdir = Keyword.get(opts, :outdir, "priv/static/assets") |> Path.expand()
    target = opts |> Keyword.get(:target, "") |> to_string()
    minify = Keyword.get(opts, :minify, true)
    sourcemap_opt = Keyword.get(opts, :sourcemap, true)
    sourcemap = sourcemap_opt != false
    define = Keyword.get(opts, :define, %{})
    mode = Keyword.get(opts, :mode, "production")
    aliases = Keyword.get(opts, :aliases, %{})
    plugins = Keyword.get(opts, :plugins, [])
    code_splitting = Keyword.get(opts, :code_splitting, true)
    chunks = Keyword.get(opts, :chunks, %{})
    external_raw = Keyword.get(opts, :external, [])
    {external_set, external_globals} = normalize_external(external_raw)

    first_entry = hd(entries)

    node_modules =
      Keyword.get(opts, :node_modules) ||
        NPM.PackageResolver.find_node_modules(Path.dirname(first_entry))

    resolve_dirs = Keyword.get(opts, :resolve_dirs, []) |> Enum.map(&Path.expand/1)
    loaders = Keyword.get(opts, :loaders, %{})
    hash = Keyword.get(opts, :hash, true)
    name = Keyword.get(opts, :name)

    env_define = Volt.Env.define(mode: mode, root: File.cwd!())
    all_define = Map.merge(env_define, define)

    ctx = %{
      node_modules: node_modules,
      resolve_dirs: resolve_dirs,
      aliases: aliases,
      plugins: plugins,
      external: external_set,
      external_globals: external_globals,
      loaders: loaders
    }

    bundle_opts = [
      minify: minify,
      sourcemap: sourcemap,
      target: target,
      define: all_define
    ]

    build_ctx = %{
      outdir: outdir,
      target: target,
      hash: hash,
      bundle_opts: bundle_opts,
      code_splitting: code_splitting,
      sourcemap_hidden: sourcemap_opt == :hidden,
      chunks: chunks
    }

    results =
      Enum.flat_map(entries, fn entry ->
        expand_entry(entry, name)
        |> Enum.map(fn {entry_path, entry_type, entry_name} ->
          build_entry(entry_path, entry_type, entry_name, ctx, build_ctx)
        end)
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {[single], []} -> single
      {successes, []} when successes != [] -> {:ok, merge_build_results(successes)}
      {_, [first_error | _]} -> first_error
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
         {:ok, compiled} <- compile_all(modules, target, ctx.plugins, ctx.loaders) do
      compiled = rewrite_nonlocal_labels(compiled, specifier_labels, path_labels)

      output_ctx = %{
        plugins: ctx.plugins,
        external_set: ctx.external,
        external_globals: ctx.external_globals,
        workers: workers,
        worker_results: build_worker_results(workers, ctx, build_ctx)
      }

      out = %{
        outdir: outdir,
        hash: hash,
        bundle_opts: bundle_opts,
        ctx: output_ctx,
        sourcemap_hidden: build_ctx.sourcemap_hidden,
        chunks: build_ctx.chunks
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
    %{outdir: outdir, hash: hash, bundle_opts: bundle_opts} = build_ctx

    with {:ok, source} <- File.read(entry),
         {:ok, compiled} <-
           Volt.Pipeline.compile(entry, source, minify: bundle_opts[:minify] || false) do
      Volt.Builder.Writer.build_style_entry(name, compiled.code, outdir, hash)
    end
  end

  defp has_dynamic_imports?(dep_map) do
    Enum.any?(dep_map, fn {_, %{dynamic: dyn}} -> dyn != [] end)
  end

  defp build_worker_results(workers, ctx, build_ctx) do
    workers
    |> Enum.flat_map(fn {_importer, spec_map} -> Map.to_list(spec_map) end)
    |> Enum.uniq_by(fn {_specifier, resolved_path} -> resolved_path end)
    |> Enum.reduce(%{}, fn {_specifier, resolved_path}, acc ->
      if Map.has_key?(acc, resolved_path) do
        acc
      else
        worker_name = resolved_path |> Path.basename() |> Path.rootname()

        case build_entry(
               resolved_path,
               :script,
               worker_name,
               ctx,
               %{build_ctx | code_splitting: false}
             ) do
          {:ok, %{js: %{path: path}}} -> Map.put(acc, resolved_path, Path.basename(path))
          _ -> acc
        end
      end
    end)
  end

  # ── Module compilation ──────────────────────────────────────────────

  defp compile_all(modules, target, plugins, loaders) do
    {batch, special} = split_batchable(modules, plugins, loaders)

    transform_opts = if target != "", do: [target: target], else: []
    batch_inputs = Enum.map(batch, fn {source, filename, _label} -> {source, filename} end)

    with {:ok, batch_compiled} <- compile_batch(batch, batch_inputs, transform_opts),
         {:ok, special_compiled} <- compile_special(special, target, plugins, loaders) do
      merge_compiled(batch_compiled, special_compiled)
    end
  end

  defp split_batchable(modules, plugins, loaders) do
    {batch, special} =
      Enum.reduce(modules, {[], []}, fn {path, _label, _source} = mod, {b, s} ->
        if batchable?(path, plugins) do
          {_path, label, source} = mod
          filename = Volt.JS.Extensions.apply_loader(Path.basename(path), loaders)
          {[{source, filename, label} | b], s}
        else
          {b, [mod | s]}
        end
      end)

    {Enum.reverse(batch), Enum.reverse(special)}
  end

  defp compile_batch(_batch, [], _opts), do: {:ok, []}

  defp compile_batch(batch, inputs, opts) do
    batch
    |> Enum.zip(OXC.transform_many(inputs, opts))
    |> Enum.reduce_while([], fn
      {{_, _, label}, {:ok, code}}, acc when is_binary(code) ->
        {:cont, [{label, code, nil} | acc]}

      {{_, _, label}, {:ok, %{code: code, sourcemap: sm}}}, acc ->
        {:cont, [{label, code, sm} | acc]}

      {_, {:error, _} = error}, _acc ->
        {:halt, error}
    end)
    |> then(fn
      list when is_list(list) -> {:ok, list}
      {:error, _} = error -> error
    end)
  end

  defp compile_special(special, target, plugins, loaders) do
    Enum.reduce_while(special, {:ok, []}, fn {path, label, source}, {:ok, acc} ->
      case compile_module(path, label, source, target, plugins, loaders) do
        {:ok, js, css} -> {:cont, {:ok, [{label, js, css} | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp merge_compiled(batch, special) do
    all = Enum.reverse(batch) ++ Enum.reverse(special)

    {js_files, css_parts} =
      Enum.reduce(all, {[], []}, fn {label, js, css}, {js_acc, css_acc} ->
        {[{label, js} | js_acc], if(css, do: [css | css_acc], else: css_acc)}
      end)

    {:ok, {Enum.reverse(js_files), Enum.reverse(css_parts)}}
  end

  defp batchable?(path, plugins) do
    not Volt.Assets.asset?(path) and
      Path.extname(path) in Volt.JS.Extensions.js() and
      plugins == []
  end

  defp compile_module(path, _label, source, target, plugins, loaders) do
    if Volt.Assets.asset?(path) do
      case Volt.Assets.to_js_module(path) do
        {:ok, js} -> {:ok, js, nil}
        {:error, _} = error -> error
      end
    else
      case Volt.Pipeline.compile(path, source, target: target, plugins: plugins, loaders: loaders) do
        {:ok, %{code: code, css: css}} -> {:ok, code, css}
        {:error, _} = error -> error
      end
    end
  end

  defp rewrite_nonlocal_labels({js_files, css_parts}, specifier_labels, path_labels) do
    label_to_path = Map.new(path_labels, fn {path, label} -> {label, path} end)

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

        new_code = rewrite_imports_to_labels(code, rewrite_map)
        {label, new_code}
      end)

    {js_files, css_parts}
  end

  defp relative_label(from_label, to_label) do
    from_dir = Path.dirname(from_label)
    Path.relative_to(to_label, from_dir)
  end

  defp rewrite_imports_to_labels(code, label_map) do
    case OXC.rewrite_specifiers(code, "module.js", &rewrite_specifier(&1, label_map)) do
      {:ok, rewritten} -> rewritten
      {:error, _} -> code
    end
  end

  @css_exts Volt.JS.Extensions.css()
  defp rewrite_specifier(specifier, label_map) do
    if Path.extname(specifier) in @css_exts do
      {:rewrite, "data:text/css,"}
    else
      case Map.fetch(label_map, specifier) do
        {:ok, new_label} -> {:rewrite, "./" <> new_label}
        :error -> :keep
      end
    end
  end

  defp expand_entry(entry, override_name) do
    if Volt.HTMLEntry.html?(entry) do
      {:ok, %{scripts: scripts, styles: styles}} = Volt.HTMLEntry.extract(entry)

      Enum.map(scripts, &{&1, :script, Path.basename(&1) |> Path.rootname()}) ++
        Enum.map(styles, &{&1, :style, Path.basename(&1) |> Path.rootname()})
    else
      type = if Path.extname(entry) == ".css", do: :style, else: :script
      entry_name = override_name || entry |> Path.basename() |> Path.rootname()
      [{entry, type, entry_name}]
    end
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

  defp merge_build_results(results) do
    Enum.reduce(results, %{js: [], css: nil, manifest: %{}}, fn {:ok, result}, acc ->
      %{
        js: [result.js | acc.js],
        css: result.css || acc.css,
        manifest: Map.merge(acc.manifest, result.manifest)
      }
    end)
  end
end
