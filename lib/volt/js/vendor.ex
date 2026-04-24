defmodule Volt.JS.Vendor do
  @moduledoc """
  Pre-bundle vendor (node_modules) dependencies for dev mode.

  Scans source files with `OXC.imports/2`, identifies bare specifiers
  (non-relative, non-URL), resolves them through `node_modules`, and
  bundles each into a single ESM file with `OXC.bundle/2`.

  CJS packages (e.g. React) are automatically converted to ESM during
  bundling. `process.env.NODE_ENV` is replaced with `"development"`
  so conditional CJS branches resolve correctly.

  Cross-package CJS `require()` calls (e.g. `react-dom` requiring `react`)
  are rewritten to ESM imports pointing at other `/@vendor/` modules.

  Bundled files are cached on disk in `_build/volt/vendor/`.
  """

  require Logger

  defp cache_dir do
    build_path = System.get_env("MIX_BUILD_PATH") || "_build"
    Path.join(build_path, "volt/vendor")
  end

  @doc """
  Scan source files and pre-bundle any bare npm imports.

  Returns a map of `specifier → vendor_path` for import rewriting.

  ## Options

    * `:root` — source directory to scan
    * `:node_modules` — path to node_modules (default: auto-detect)
    * `:force` — rebuild even if cached (default: `false`)
  """
  @spec prebundle(keyword()) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
  def prebundle(opts) do
    root = Keyword.fetch!(opts, :root)
    force = Keyword.get(opts, :force, false)
    node_modules = opts[:node_modules] || NPM.Resolution.PackageResolver.find_node_modules(root)

    plugins = Keyword.get(opts, :plugins, [])

    with {:ok, specifiers} <- scan_bare_imports(root, plugins),
         :ok <- ensure_cache_dir() do
      vendor_map =
        specifiers
        |> Enum.uniq()
        |> Enum.reduce(%{}, fn spec, acc ->
          case safe_bundle_vendor(spec, node_modules, force) do
            {:ok, path} -> Map.put(acc, spec, path)
            {:error, _} -> acc
          end
        end)

      {:ok, vendor_map}
    end
  end

  @doc """
  Bundle a single vendor specifier on demand.

  Used by the dev server when a `/@vendor/` request arrives for a
  specifier that wasn't caught by `prebundle/1` (e.g. transitive
  dependency, or newly added import).
  """
  @spec bundle_on_demand(String.t(), String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  def bundle_on_demand(specifier, node_modules) do
    ensure_cache_dir()

    case bundle_vendor(specifier, node_modules, false) do
      {:ok, path} -> File.read(path)
      {:error, _} = error -> error
    end
  end

  @doc """
  Get the URL path for a vendor module.
  """
  @spec vendor_url(String.t()) :: String.t()
  def vendor_url(specifier) do
    "/@vendor/#{encode_specifier(specifier)}.js"
  end

  @doc """
  Read a pre-bundled vendor file by specifier.
  """
  @spec read(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def read(specifier) do
    path = cache_path(specifier)

    case File.read(path) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :not_found}
    end
  end

  # ── Scanning ──────────────────────────────────────────────────────

  defp scan_bare_imports(root, plugins) do
    source_files =
      Volt.JS.Extensions.scannable(plugins)
      |> Enum.flat_map(fn ext -> Path.wildcard(Path.join(root, "**/*" <> ext)) end)
      |> Enum.uniq()

    specifiers =
      Enum.flat_map(source_files, fn file ->
        with {:ok, source} <- File.read(file),
             {:ok, imports} <- extract_imports(source, file, plugins) do
          Enum.filter(imports, &NPM.Resolution.PackageResolver.bare?/1)
        else
          _ -> []
        end
      end)

    {:ok, specifiers}
  end

  defp extract_imports(source, path, plugins) do
    case Volt.PluginRunner.extract_imports(plugins, path, source, []) do
      {:ok, %{imports: imports}} -> {:ok, Enum.map(imports, fn {_type, spec} -> spec end)}
      nil -> OXC.imports(source, Path.basename(path))
      {:error, _} = error -> error
    end
  end

  # ── Bundling ──────────────────────────────────────────────────────

  defp safe_bundle_vendor(specifier, node_modules, force) do
    bundle_vendor(specifier, node_modules, force)
  rescue
    exception ->
      Logger.debug(
        "[Volt] Vendor prebundle skipped #{specifier}: #{Exception.message(exception)}"
      )

      {:error, exception}
  end

  defp bundle_vendor(specifier, node_modules, force) do
    path = cache_path(specifier)

    if not force and File.regular?(path) do
      {:ok, path}
    else
      do_bundle_vendor(specifier, node_modules, path)
    end
  end

  defp do_bundle_vendor(specifier, node_modules, output_path) do
    case resolve_package_entry(specifier, node_modules) do
      {:ok, entry_path} ->
        {package_name, _subpath} = NPM.Resolution.PackageResolver.split_specifier(specifier)
        package_dir = Path.join(node_modules, package_name)

        files = collect_package_files(entry_path, package_dir, node_modules)
        entry_label = entry_label(entry_path, node_modules)

        bundle_opts = [
          entry: entry_label,
          format: :esm
        ]

        case OXC.bundle(files, bundle_opts) do
          {:ok, result} ->
            code = extract_code(result) |> rewrite_cross_package_requires()
            File.write!(output_path, code)
            {:ok, output_path}

          {:error, _} = error ->
            error
        end

      :error ->
        {:error, {:not_found, specifier}}
    end
  end

  defp collect_package_files(entry_path, package_dir, node_modules) do
    project_root = common_root(entry_path, node_modules)
    entry_label = Path.relative_to(entry_path, project_root)

    package_files =
      package_dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&(Path.extname(&1) in Volt.JS.Extensions.bundleable() and File.regular?(&1)))
      |> Enum.map(fn path ->
        label = Path.relative_to(path, project_root)
        {label, File.read!(path)}
      end)

    has_entry = Enum.any?(package_files, fn {label, _} -> label == entry_label end)

    if has_entry do
      package_files
    else
      [{entry_label, File.read!(entry_path)} | package_files]
    end
  end

  # ── Cross-package require rewriting ───────────────────────────────

  defp rewrite_cross_package_requires(code) do
    case OXC.parse(code, "vendor.js") do
      {:ok, ast} ->
        {_ast, %{calls: calls, decl: decl}} =
          OXC.postwalk(ast, %{calls: [], decl: nil}, &collect_require_info/2)

        deps = calls |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

        if deps == [] do
          code
        else
          apply_require_rewrite(code, deps, decl)
        end

      {:error, _} ->
        code
    end
  end

  defp collect_require_info(
         %{type: :variable_declaration, declarations: decls, start: s, end: e} = node,
         acc
       ) do
    if Enum.any?(decls, &match?(%{id: %{name: "__require"}}, &1)) do
      {node, %{acc | decl: %{start: s, end: e}}}
    else
      {node, acc}
    end
  end

  defp collect_require_info(
         %{
           type: :call_expression,
           callee: %{type: :identifier, name: "__require"},
           arguments: [%{type: :literal, value: spec}]
         } = node,
         acc
       )
       when is_binary(spec) do
    {node, %{acc | calls: [{spec, node.start, node.end} | acc.calls]}}
  end

  defp collect_require_info(node, acc), do: {node, acc}

  defp apply_require_rewrite(code, deps, decl) do
    safe_name = fn spec -> "__vendor_" <> String.replace(spec, ~r/[^a-zA-Z0-9]/, "_") end

    import_stmts =
      Enum.map(deps, fn spec ->
        "import * as #{safe_name.(spec)} from '#{vendor_url(spec)}';"
      end)

    prop_stmts =
      Enum.map(deps, fn spec ->
        ~s|"#{spec}": #{safe_name.(spec)}|
      end)

    preamble =
      OXC.parse!("$imports\nvar __require = (id) => ({$entries})[id];", "shim.js")
      |> OXC.splice(:imports, import_stmts)
      |> OXC.splice(:entries, prop_stmts)
      |> OXC.codegen!()

    if decl do
      shim_code =
        OXC.parse!("var __require = (id) => ({$entries})[id];", "shim.js")
        |> OXC.splice(:entries, prop_stmts)
        |> OXC.codegen!()
        |> String.trim_trailing()

      preamble <> OXC.patch_string(code, [%{start: decl.start, end: decl.end, change: shim_code}])
    else
      preamble <> code
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp entry_label(entry_path, node_modules) do
    project_root = common_root(entry_path, node_modules)
    Path.relative_to(entry_path, project_root)
  end

  defp common_root(entry_path, node_modules) do
    entry_parts = Path.split(entry_path)
    nm_parts = Path.split(node_modules)

    Enum.zip(entry_parts, nm_parts)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(&elem(&1, 0))
    |> Path.join()
  end

  defp extract_code(result) when is_binary(result), do: result
  defp extract_code(%{code: code}), do: code

  defp resolve_package_entry(specifier, node_modules) when is_binary(node_modules) do
    Volt.JS.PackageResolver.resolve(specifier, node_modules,
      extensions: Volt.JS.Extensions.resolvable()
    )
  end

  defp resolve_package_entry(_specifier, nil), do: :error

  defp ensure_cache_dir do
    File.mkdir_p!(cache_dir())
    :ok
  end

  defp cache_path(specifier) do
    Path.join(cache_dir(), encode_specifier(specifier) <> ".js")
  end

  @doc "Encode a specifier for use in URLs (escaping @ and /)."
  def encode_specifier(specifier) do
    specifier
    |> String.replace("@", "__at__")
    |> String.replace("/", "__slash__")
  end

  @doc "Decode a URL-safe specifier back to its original form."
  def decode_specifier(encoded) do
    encoded
    |> String.replace("__slash__", "/")
    |> String.replace("__at__", "@")
  end
end
