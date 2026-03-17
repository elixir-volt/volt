defmodule Volt.Builder do
  @moduledoc """
  Production build — resolve dependencies, split chunks, bundle, and write assets.

  Walks the dependency graph from entry files, splits code at dynamic import
  boundaries, compiles everything through the Pipeline, bundles each chunk
  with `OXC.bundle/2`, and writes content-hashed output files with a manifest.
  """

  alias Volt.Builder.{Collector, Output}
  alias Volt.PackageResolver

  @type build_result :: %{
          js: %{path: String.t(), size: non_neg_integer()} | [%{path: String.t(), size: non_neg_integer()}],
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
    sourcemap = Keyword.get(opts, :sourcemap, true)
    define = Keyword.get(opts, :define, %{})
    mode = Keyword.get(opts, :mode, "production")
    aliases = Keyword.get(opts, :aliases, %{})
    plugins = Keyword.get(opts, :plugins, [])
    code_splitting = Keyword.get(opts, :code_splitting, true)
    external_raw = Keyword.get(opts, :external, [])
    {external_set, external_globals} = normalize_external(external_raw)

    first_entry = hd(entries)
    node_modules = Keyword.get(opts, :node_modules) || PackageResolver.find_node_modules(Path.dirname(first_entry))
    resolve_dirs = Keyword.get(opts, :resolve_dirs, []) |> Enum.map(&Path.expand/1)
    hash = Keyword.get(opts, :hash, true)
    name = Keyword.get(opts, :name)

    env_define = Volt.Env.define(mode: mode, root: File.cwd!())
    define = Map.merge(env_define, define)

    ctx = %{
      node_modules: node_modules,
      resolve_dirs: resolve_dirs,
      aliases: aliases,
      plugins: plugins,
      external: external_set,
      external_globals: external_globals
    }

    bundle_opts = [
      minify: minify,
      sourcemap: sourcemap,
      target: target,
      define: define
    ]

    results =
      Enum.map(entries, fn entry ->
        entry_name = name || entry |> Path.basename() |> Path.rootname()
        build_entry(entry, entry_name, ctx, outdir, target, hash, bundle_opts, code_splitting)
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {[single], []} -> single
      {successes, []} when successes != [] -> {:ok, merge_build_results(successes)}
      {_, [first_error | _]} -> first_error
    end
  end

  defp build_entry(entry, name, ctx, outdir, target, hash, bundle_opts, code_splitting) do
    with {:ok, modules, dep_map} <- Collector.collect(entry, ctx),
         {:ok, compiled} <- compile_all(modules, target, ctx.plugins) do
      output_ctx = %{plugins: ctx.plugins, external_set: ctx.external, external_globals: ctx.external_globals}

      if code_splitting and has_dynamic_imports?(dep_map) do
        Output.build_chunks(entry, name, modules, dep_map, compiled, outdir, hash, bundle_opts, output_ctx)
      else
        Output.build_single(name, compiled, outdir, hash, bundle_opts, output_ctx)
      end
    end
  end

  defp has_dynamic_imports?(dep_map) do
    Enum.any?(dep_map, fn {_, %{dynamic: dyn}} -> dyn != [] end)
  end

  # ── Module compilation ──────────────────────────────────────────────

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
        compile_vue(source, path)

      Volt.CSSModules.css_module?(path) ->
        {:ok, js, css} = Volt.CSSModules.compile(source, Path.basename(path))
        {:ok, js, css}

      ext == ".json" ->
        {:ok, "export default #{source};\n", nil}

      Volt.Assets.asset?(path) ->
        case Volt.Assets.to_js_module(path) do
          {:ok, js} -> {:ok, js, nil}
          {:error, _} = error -> error
        end

      true ->
        with {:ok, js, css} <- compile_js(source, path, target) do
          {:ok, Volt.PluginRunner.transform(plugins, js, path), css}
        end
    end
  end

  defp compile_vue(source, path) do
    case Vize.compile_sfc(source, filename: Path.basename(path)) do
      {:ok, result} -> {:ok, result.code, result.css}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compile_js(source, path, target) do
    case OXC.transform(source, Path.basename(path), target: target) do
      {:ok, code} when is_binary(code) -> {:ok, code, nil}
      {:ok, %{code: code}} -> {:ok, code, nil}
      {:error, errors} -> {:error, errors}
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

  defp derive_global_name(specifier) do
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
