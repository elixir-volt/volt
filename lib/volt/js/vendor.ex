defmodule Volt.JS.Vendor do
  @moduledoc """
  Pre-bundle vendor (node_modules) dependencies for dev mode.

  Scans source files with `OXC.imports/2`, identifies bare specifiers
  (non-relative, non-URL), resolves them through `node_modules`, and
  bundles each into a single file with `OXC.bundle/2`.

  Bundled files are cached on disk in `_build/volt/vendor/`.
  """

  alias QuickBEAM.JS.Bundler
  alias Volt.Builder.BundleResult

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
    node_modules = opts[:node_modules] || NPM.PackageResolver.find_node_modules(root)

    with {:ok, specifiers} <- scan_bare_imports(root),
         :ok <- ensure_cache_dir() do
      vendor_map =
        specifiers
        |> Enum.uniq()
        |> Enum.reduce(%{}, fn spec, acc ->
          case bundle_vendor(spec, node_modules, force) do
            {:ok, path} -> Map.put(acc, spec, path)
            {:error, _} -> acc
          end
        end)

      {:ok, vendor_map}
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

  defp scan_bare_imports(root) do
    source_files =
      ["ts", "tsx", "js", "jsx", "mts", "mjs", "vue"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, "**/*.#{&1}")))
      |> Enum.uniq()

    specifiers =
      Enum.flat_map(source_files, fn file ->
        source = File.read!(file)
        filename = Path.basename(file)

        case extract_imports(source, filename) do
          {:ok, imports} -> Enum.filter(imports, &NPM.PackageResolver.bare?/1)
          {:error, _} -> []
        end
      end)

    {:ok, specifiers}
  end

  defp extract_imports(source, filename) do
    ext = Path.extname(filename)

    if ext == ".vue" do
      Volt.JS.VueImports.extract(source)
    else
      OXC.imports(source, filename)
    end
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
        case Bundler.bundle_file(entry_path, node_modules: node_modules) do
          {:ok, result} ->
            File.write!(output_path, BundleResult.code(result))
            {:ok, output_path}

          {:error, _} = error ->
            error
        end

      :error ->
        {:error, {:not_found, specifier}}
    end
  end

  defp resolve_package_entry(specifier, node_modules) when is_binary(node_modules) do
    {package_name, subpath} = NPM.PackageResolver.split_specifier(specifier)
    package_dir = Path.join(node_modules, package_name)

    NPM.PackageResolver.resolve_entry(package_dir,
      subpath: subpath || ".",
      extensions: Volt.Extensions.resolvable()
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
