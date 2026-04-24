defmodule Volt.JS.Vendor do
  @moduledoc """
  Pre-bundle vendor (node_modules) dependencies for dev mode.

  Scans source files with `OXC.imports/2`, identifies bare specifiers
  (non-relative, non-URL), resolves them through `node_modules`, and
  bundles each into a single ESM file with `OXC.bundle/2`.

  CJS packages (e.g. React) are automatically converted to ESM during
  bundling. `process.env.NODE_ENV` is replaced with `"development"`
  so conditional CJS branches resolve correctly.

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
        |> Enum.map(&Volt.PluginRunner.prebundle_alias(plugins, &1))
        |> Enum.uniq()
        |> Enum.reduce(%{}, fn spec, acc ->
          case safe_bundle_vendor(spec, node_modules, force, plugins) do
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
  @spec bundle_on_demand(String.t(), String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def bundle_on_demand(specifier, node_modules, plugins \\ []) do
    ensure_cache_dir()
    specifier = Volt.PluginRunner.prebundle_alias(plugins, specifier)

    case bundle_vendor(specifier, node_modules, false, plugins) do
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

  defp safe_bundle_vendor(specifier, node_modules, force, plugins) do
    bundle_vendor(specifier, node_modules, force, plugins)
  rescue
    exception ->
      Logger.debug(
        "[Volt] Vendor prebundle skipped #{specifier}: #{Exception.message(exception)}"
      )

      {:error, exception}
  end

  defp bundle_vendor(specifier, node_modules, force, plugins) do
    path = cache_path(specifier)

    if not force and File.regular?(path) do
      {:ok, path}
    else
      do_bundle_vendor(specifier, node_modules, path, plugins)
    end
  end

  defp do_bundle_vendor(specifier, node_modules, output_path, plugins) do
    case prebundle_entry(specifier, node_modules, plugins) do
      {:ok, entry_path, project_root} ->
        bundle_opts = [
          cwd: project_root,
          format: :esm,
          conditions: Volt.JS.PackageResolver.browser_conditions(),
          modules: [node_modules],
          define: %{"process.env.NODE_ENV" => ~s("development")},
          exports: :named,
          preserve_entry_signatures: :strict
        ]

        case OXC.bundle(entry_path, bundle_opts) do
          {:ok, result} ->
            File.write!(output_path, extract_code(result))
            {:ok, output_path}

          {:error, _} = error ->
            error
        end

      :error ->
        {:error, {:not_found, specifier}}
    end
  end

  defp prebundle_entry(specifier, node_modules, plugins) do
    case Volt.PluginRunner.prebundle_entry(plugins, specifier) do
      {:source, filename, source} ->
        synthetic_prebundle_entry(specifier, filename, source, node_modules)

      {:proxy, filename, _opts} = entry ->
        synthetic_prebundle_entry(
          specifier,
          filename,
          Volt.JS.PrebundleEntry.source(entry),
          node_modules
        )

      nil ->
        package_prebundle_entry(specifier, node_modules)
    end
  end

  defp synthetic_prebundle_entry(specifier, filename, source, node_modules) do
    dir = Path.join([cache_dir(), "entries", encode_specifier(specifier)])
    path = Path.join(dir, filename)
    File.mkdir_p!(dir)
    File.write!(path, source)
    {:ok, path, Path.dirname(node_modules)}
  end

  defp package_prebundle_entry(specifier, node_modules) do
    case resolve_package_entry(specifier, node_modules) do
      {:ok, entry_path} -> {:ok, entry_path, package_project_root(entry_path, node_modules)}
      :error -> :error
    end
  end

  defp package_project_root(entry_path, node_modules) do
    entry_path
    |> Path.dirname()
    |> NPM.Resolution.PackageResolver.nearest_package()
    |> case do
      {:ok, package_dir, _package} -> Path.dirname(package_dir)
      :error -> Path.dirname(node_modules)
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────

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
