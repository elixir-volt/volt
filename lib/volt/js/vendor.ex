defmodule Volt.JS.Vendor do
  @moduledoc """
  Pre-bundle vendor (node_modules) dependencies for dev mode.

  Scans source files with `OXC.imports/2`, identifies bare specifiers
  (non-relative, non-URL), resolves them through module directories, and
  bundles each into a single ESM file with `OXC.bundle/2`.

  CJS packages (e.g. React) are automatically converted to ESM during
  bundling. `process.env.NODE_ENV` is replaced with `"development"`
  so conditional CJS branches resolve correctly.

  Bundled files are cached on disk in `_build/volt/vendor/`.
  """

  require Logger

  alias OXC.Bundle

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
    * `:resolve_dirs` — additional package directories to resolve from
    * `:force` — rebuild even if cached (default: `false`)
  """
  @spec prebundle(keyword()) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
  def prebundle(opts) do
    root = Keyword.fetch!(opts, :root)
    force = Keyword.get(opts, :force, false)
    node_modules = opts[:node_modules] || NPM.Resolution.PackageResolver.find_node_modules(root)
    module_dirs = module_dirs(node_modules, Keyword.get(opts, :resolve_dirs, []))

    plugins = Keyword.get(opts, :plugins, [])
    module_types = Keyword.get(opts, :module_types, %{})

    with {:ok, specifiers} <- scan_bare_imports(root, plugins),
         :ok <- ensure_cache_dir() do
      specifiers =
        specifiers
        |> Enum.map(&Volt.PluginRunner.prebundle_alias(plugins, &1))
        |> Enum.uniq()

      prebundle_vendors(specifiers, module_dirs, force, plugins, module_types)
    end
  end

  @doc """
  Bundle a single vendor specifier on demand.

  Used by the dev server when a `/@vendor/` request arrives for a
  specifier that wasn't caught by `prebundle/1` (e.g. transitive
  dependency, or newly added import).
  """
  @spec bundle_on_demand(String.t(), String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def bundle_on_demand(specifier, node_modules, opts \\ []) do
    ensure_cache_dir()
    {plugins, resolve_dirs, module_types} = normalize_on_demand_opts(opts)
    module_dirs = module_dirs(node_modules, resolve_dirs)
    specifier = Volt.PluginRunner.prebundle_alias(plugins, specifier)

    case bundle_vendor(specifier, module_dirs, false, plugins, module_types) do
      {:ok, path} -> File.read(path)
      {:error, _} = error -> error
    end
  end

  @doc """
  Get the URL path for a vendor module.
  """
  @spec vendor_url(String.t()) :: String.t()
  def vendor_url(specifier), do: "/@vendor/#{encode_specifier(specifier)}.js"

  @doc "Get the URL path for a vendor module with a cache-busting browser hash."
  @spec vendor_url(String.t(), keyword()) :: String.t()
  def vendor_url(specifier, opts) do
    specifier
    |> vendor_url()
    |> Volt.URL.append_query("v=#{browser_hash(opts)}")
  end

  @doc "Return whether a request browser hash matches the current optimized dependency state."
  @spec current_browser_hash?(String.t() | nil, keyword()) :: boolean()
  def current_browser_hash?(nil, _opts), do: true
  def current_browser_hash?(hash, opts), do: hash == browser_hash(opts)

  @doc "Return the current browser hash for optimized dependency requests."
  @spec browser_hash(keyword()) :: String.t()
  def browser_hash(opts) do
    {plugins, resolve_dirs, module_types} = normalize_on_demand_opts(opts)
    node_modules = Keyword.get(opts, :node_modules)
    module_dirs = module_dirs(node_modules, resolve_dirs)

    :crypto.hash(
      :sha256,
      :erlang.term_to_binary(browser_signature(module_dirs, plugins, module_types))
    )
    |> Base.encode16(case: :lower)
    |> binary_part(0, 8)
  end

  @doc """
  Read a pre-bundled vendor file by specifier.
  """
  @spec read(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def read(specifier), do: read_cached(specifier)

  @doc "Read a pre-bundled vendor file when its cache signature matches the current options."
  @spec read(String.t(), keyword()) :: {:ok, String.t()} | {:error, :not_found}
  def read("chunks/" <> _ = specifier, _opts), do: read_cached(specifier)

  def read(specifier, opts) do
    {plugins, resolve_dirs, module_types} = normalize_on_demand_opts(opts)
    node_modules = Keyword.get(opts, :node_modules)
    module_dirs = module_dirs(node_modules, resolve_dirs)
    specifier = Volt.PluginRunner.prebundle_alias(plugins, specifier)

    if cache_fresh?(specifier, module_dirs, plugins, module_types) do
      read_cached(specifier)
    else
      {:error, :not_found}
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

  defp prebundle_vendors([], _module_dirs, _force, _plugins, _module_types), do: {:ok, %{}}

  defp prebundle_vendors(specifiers, module_dirs, force, plugins, module_types) do
    vendor_map = Map.new(specifiers, &{&1, cache_path(&1)})

    if not force and Enum.all?(specifiers, &cache_fresh?(&1, module_dirs, plugins, module_types)) do
      {:ok, vendor_map}
    else
      safe_bundle_vendors(specifiers, module_dirs, plugins, module_types, vendor_map)
    end
  end

  defp safe_bundle_vendors(specifiers, module_dirs, plugins, module_types, vendor_map) do
    bundle_vendors(specifiers, module_dirs, plugins, module_types, vendor_map)
  rescue
    exception ->
      Logger.debug(
        "[Volt] Vendor prebundle fell back to per-package bundling: #{Exception.message(exception)}"
      )

      fallback_bundle_vendors(specifiers, module_dirs, plugins, module_types)
  end

  defp bundle_vendors(specifiers, module_dirs, plugins, module_types, vendor_map) do
    entries =
      specifiers
      |> Enum.map(&bundle_entry_for(&1, module_dirs, plugins))
      |> Enum.flat_map(fn
        {:ok, specifier, entry} -> [{specifier, entry}]
        {:error, _} -> []
      end)

    case entries do
      [] ->
        {:ok, %{}}

      entries ->
        run_vendor_bundle(entries, specifiers, module_dirs, plugins, module_types, vendor_map)
    end
  end

  defp run_vendor_bundle(entries, specifiers, module_dirs, plugins, module_types, vendor_map) do
    bundled_specifiers = Enum.map(entries, fn {specifier, _entry} -> specifier end)
    bundle_entries = Enum.map(entries, fn {_specifier, entry} -> entry end)

    bundle =
      Bundle.new()
      |> Bundle.entries(bundle_entries)
      |> Bundle.cwd(project_root(module_dirs))
      |> Bundle.outdir(cache_dir())
      |> Bundle.format(:esm)
      |> Bundle.resolve(
        conditions: Volt.JS.Resolution.browser_conditions(),
        modules: module_dirs
      )
      |> Bundle.transform(
        define: %{"process.env.NODE_ENV" => ~s("development")},
        module_types: module_types
      )
      |> Bundle.output(
        entry_file_names: "[name].js",
        chunk_file_names: "chunks/[name]-[hash].js",
        exports: :named,
        preserve_entry_signatures: :strict
      )

    case Bundle.run(bundle) do
      {:ok, _result} ->
        write_vendor_cache_metadata(bundled_specifiers, module_dirs, plugins, module_types)
        {:ok, Map.take(vendor_map, bundled_specifiers)}

      {:error, errors} ->
        Logger.debug("[Volt] Vendor multi-entry prebundle failed: #{inspect(errors)}")
        fallback_bundle_vendors(specifiers, module_dirs, plugins, module_types)
    end
  end

  defp write_vendor_cache_metadata(specifiers, module_dirs, plugins, module_types) do
    Enum.each(specifiers, fn specifier ->
      if File.regular?(cache_path(specifier)) do
        File.write!(
          cache_meta_path(specifier),
          cache_signature(specifier, module_dirs, plugins, module_types)
        )
      end
    end)
  end

  defp fallback_bundle_vendors(specifiers, module_dirs, plugins, module_types) do
    specifiers
    |> Enum.reduce(%{}, fn specifier, acc ->
      case bundle_vendor(specifier, module_dirs, false, plugins, module_types) do
        {:ok, path} -> Map.put(acc, specifier, path)
        {:error, _} -> acc
      end
    end)
    |> then(&{:ok, &1})
  end

  defp bundle_entry_for(specifier, module_dirs, plugins) do
    case Volt.PluginRunner.prebundle_entry(plugins, specifier) do
      {:source, filename, source} ->
        {:ok, specifier, %{name: encode_specifier(specifier), import: filename, source: source}}

      {:proxy, filename, _opts} = entry ->
        {:ok, specifier,
         %{
           name: encode_specifier(specifier),
           import: filename,
           source: Volt.JS.PrebundleEntry.source(entry)
         }}

      nil ->
        case resolve_package_entry(specifier, module_dirs) do
          {:ok, entry_path} ->
            {:ok, specifier, %{name: encode_specifier(specifier), import: entry_path}}

          :error ->
            {:error, {:not_found, specifier}}
        end
    end
  end

  defp bundle_vendor(specifier, module_dirs, force, plugins, module_types) do
    path = cache_path(specifier)

    if not force and File.regular?(path) and
         cache_fresh?(specifier, module_dirs, plugins, module_types) do
      {:ok, path}
    else
      do_bundle_vendor(specifier, module_dirs, path, plugins, module_types)
    end
  end

  defp do_bundle_vendor(specifier, module_dirs, output_path, plugins, module_types) do
    case prebundle_entry(specifier, module_dirs, plugins) do
      {:ok, entry_path, project_root} ->
        bundle_opts =
          [
            cwd: project_root,
            format: :esm,
            conditions: Volt.JS.Resolution.browser_conditions(),
            modules: module_dirs,
            define: %{"process.env.NODE_ENV" => ~s("development")},
            exports: :named,
            preserve_entry_signatures: :strict
          ] ++ if(module_types != %{}, do: [module_types: module_types], else: [])

        case OXC.bundle(entry_path, bundle_opts) do
          {:ok, result} ->
            write_cache_files!(
              output_path,
              extract_code(result),
              specifier,
              module_dirs,
              plugins,
              module_types
            )

            {:ok, output_path}

          {:error, _} = error ->
            error
        end

      :error ->
        {:error, {:not_found, specifier}}
    end
  end

  defp prebundle_entry(specifier, module_dirs, plugins) do
    case Volt.PluginRunner.prebundle_entry(plugins, specifier) do
      {:source, filename, source} ->
        synthetic_prebundle_entry(specifier, filename, source, module_dirs)

      {:proxy, filename, _opts} = entry ->
        synthetic_prebundle_entry(
          specifier,
          filename,
          Volt.JS.PrebundleEntry.source(entry),
          module_dirs
        )

      nil ->
        package_prebundle_entry(specifier, module_dirs)
    end
  end

  defp synthetic_prebundle_entry(specifier, filename, source, _module_dirs) do
    dir = Path.expand(Path.join([cache_dir(), "entries", encode_specifier(specifier)]))
    path = Path.join(dir, filename)
    File.mkdir_p!(dir)
    File.write!(path, source)
    {:ok, path, dir}
  end

  defp package_prebundle_entry(specifier, module_dirs) do
    case resolve_package_entry(specifier, module_dirs) do
      {:ok, entry_path} -> {:ok, entry_path, package_project_root(entry_path, module_dirs)}
      :error -> :error
    end
  end

  defp package_project_root(entry_path, module_dirs) do
    entry_path
    |> Path.dirname()
    |> NPM.Resolution.PackageResolver.nearest_package()
    |> case do
      {:ok, package_dir, _package} -> Path.dirname(package_dir)
      :error -> project_root(module_dirs)
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp extract_code(result) when is_binary(result), do: result
  defp extract_code(%{code: code}), do: code

  defp resolve_package_entry(specifier, module_dirs) do
    Enum.find_value(module_dirs, :error, fn module_dir ->
      result =
        with :error <- resolve_from_node_modules(specifier, module_dir) do
          resolve_from_module_dir(specifier, module_dir)
        else
          {:ok, _path} = ok -> ok
        end

      case result do
        {:ok, _path} = ok -> ok
        :error -> nil
      end
    end)
  end

  defp resolve_from_node_modules(specifier, module_dir) do
    NPM.Resolution.PackageResolver.resolve(specifier, module_dir,
      extensions: Volt.JS.Extensions.resolvable(),
      conditions: Volt.JS.Resolution.browser_conditions()
    )
  end

  defp resolve_from_module_dir(specifier, module_dir) do
    {package_name, subpath} = split_specifier(specifier)
    package_dir = Path.join(module_dir, package_name)

    if File.dir?(package_dir) do
      extensions = Volt.JS.Extensions.resolvable()

      case NPM.Resolution.PackageResolver.resolve_entry(package_dir,
             subpath: subpath || ".",
             extensions: extensions,
             conditions: Volt.JS.Resolution.browser_conditions()
           ) do
        {:ok, _path} = ok -> ok
        :error -> resolve_module_dir_subpath(package_dir, subpath || ".", extensions)
      end
    else
      :error
    end
  end

  defp resolve_module_dir_subpath(package_dir, subpath, extensions) do
    path =
      subpath
      |> String.trim_leading("./")
      |> then(&Path.join(package_dir, &1))

    resolve_file_or_directory(path, extensions)
  end

  defp resolve_file_or_directory(path, extensions) do
    cond do
      File.regular?(path) ->
        {:ok, path}

      match = resolve_with_extensions(path, extensions) ->
        {:ok, match}

      File.dir?(path) ->
        resolve_with_extensions(Path.join(path, "index"), extensions)
        |> case do
          nil -> :error
          match -> {:ok, match}
        end

      true ->
        :error
    end
  end

  defp resolve_with_extensions(path, extensions) do
    Enum.find(extensions, &File.regular?(path <> &1))
    |> case do
      nil -> nil
      extension -> path <> extension
    end
  end

  defp split_specifier("@" <> rest = specifier) do
    case String.split(rest, "/", parts: 3) do
      [_scope, _name] -> {specifier, nil}
      [scope, name, subpath] -> {"@#{scope}/#{name}", "./#{subpath}"}
    end
  end

  defp split_specifier(specifier) do
    case String.split(specifier, "/", parts: 2) do
      [name] -> {name, nil}
      [name, subpath] -> {name, "./#{subpath}"}
    end
  end

  defp normalize_on_demand_opts(opts) do
    if Keyword.keyword?(opts) do
      {Keyword.get(opts, :plugins, []), Keyword.get(opts, :resolve_dirs, []),
       Keyword.get(opts, :module_types, %{})}
    else
      {opts, [], %{}}
    end
  end

  defp module_dirs(node_modules, resolve_dirs) do
    [node_modules | List.wrap(resolve_dirs)]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end

  defp project_root([module_dir | _]), do: Path.dirname(module_dir)
  defp project_root([]), do: File.cwd!()

  defp ensure_cache_dir do
    File.mkdir_p!(cache_dir())
    :ok
  end

  defp read_cached("chunks/" <> _ = specifier) do
    Path.join(cache_dir(), specifier <> ".js")
    |> File.read()
    |> case do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :not_found}
    end
  end

  defp read_cached(specifier) do
    specifier
    |> cache_path()
    |> File.read()
    |> case do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :not_found}
    end
  end

  defp cache_fresh?(specifier, module_dirs, plugins, module_types) do
    File.regular?(cache_path(specifier)) and
      File.read(cache_meta_path(specifier)) ==
        {:ok, cache_signature(specifier, module_dirs, plugins, module_types)}
  end

  defp write_cache_files!(output_path, code, specifier, module_dirs, plugins, module_types) do
    meta_path = cache_meta_path(specifier)
    nonce = System.unique_integer([:positive])
    tmp_output = "#{output_path}.#{nonce}.tmp"
    tmp_meta = "#{meta_path}.#{nonce}.tmp"

    try do
      File.write!(tmp_output, code)
      File.write!(tmp_meta, cache_signature(specifier, module_dirs, plugins, module_types))
      File.rename!(tmp_output, output_path)
      File.rename!(tmp_meta, meta_path)
    after
      File.rm(tmp_output)
      File.rm(tmp_meta)
    end
  end

  defp cache_signature(specifier, module_dirs, plugins, module_types) do
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary(signature_terms(specifier, module_dirs, plugins, module_types))
    )
    |> Base.encode16(case: :lower)
  end

  defp signature_terms(specifier, module_dirs, plugins, module_types) do
    browser_signature(module_dirs, plugins, module_types)
    |> Map.put(:specifier, specifier)
    |> Map.put(:plugins, Enum.map(plugins, &plugin_signature(&1, specifier)))
    |> Map.put(:package, package_signature(specifier, module_dirs))
  end

  defp browser_signature(module_dirs, plugins, module_types) do
    %{
      lockfiles: lockfile_signature(module_dirs),
      module_dirs: module_dirs,
      module_types: module_types,
      plugins: Enum.map(plugins, &base_plugin_signature/1)
    }
  end

  defp base_plugin_signature({module, opts}), do: {module, opts}
  defp base_plugin_signature(module), do: module

  defp plugin_signature({module, opts}, specifier),
    do: {module, opts, plugin_entry_signature(module, specifier)}

  defp plugin_signature(module, specifier),
    do: {module, plugin_entry_signature(module, specifier)}

  defp plugin_entry_signature(module, specifier) do
    if function_exported?(module, :prebundle_entry, 1) do
      module.prebundle_entry(specifier)
    end
  end

  defp package_signature(specifier, module_dirs) do
    case resolve_package_entry(specifier, module_dirs) do
      {:ok, entry_path} ->
        {entry_path, file_signature(entry_path), package_json_signature(entry_path)}

      :error ->
        :error
    end
  end

  defp package_json_signature(entry_path) do
    entry_path
    |> Path.dirname()
    |> NPM.Resolution.PackageResolver.nearest_package()
    |> case do
      {:ok, package_dir, _package} -> file_signature(Path.join(package_dir, "package.json"))
      :error -> nil
    end
  end

  @lockfiles ~w(package-lock.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb)

  defp lockfile_signature(module_dirs) do
    module_dirs
    |> lockfile_roots()
    |> Enum.flat_map(&lockfiles_in/1)
  end

  defp lockfile_roots([]), do: [File.cwd!()]

  defp lockfile_roots(module_dirs) do
    module_dirs
    |> Enum.map(&Path.dirname/1)
    |> Kernel.++([File.cwd!()])
    |> Enum.uniq()
  end

  defp lockfiles_in(root) do
    @lockfiles
    |> Enum.map(&Path.join(root, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&{&1, file_signature(&1)})
  end

  defp file_signature(path) do
    case File.read(path) do
      {:ok, contents} -> :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
      {:error, _} -> nil
    end
  end

  defp cache_path(specifier) do
    Path.join(cache_dir(), encode_specifier(specifier) <> ".js")
  end

  defp cache_meta_path(specifier), do: cache_path(specifier) <> ".meta"

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
