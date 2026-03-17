defmodule Volt.Vendor do
  @moduledoc """
  Pre-bundle vendor (node_modules) dependencies for dev mode.

  Scans source files with `OXC.imports/2`, identifies bare specifiers
  (non-relative, non-URL), resolves them through `node_modules`, and
  bundles each into a single file with `OXC.bundle/2`.

  Bundled files are cached on disk in `_build/volt/vendor/`.
  """

  alias Volt.PackageResolver

  @cache_dir "_build/volt/vendor"

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
    node_modules = opts[:node_modules] || PackageResolver.find_node_modules(root)

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
      Path.join(root, "**/*.{ts,tsx,js,jsx,mts,mjs,vue}")
      |> Path.wildcard()

    specifiers =
      Enum.flat_map(source_files, fn file ->
        source = File.read!(file)
        filename = Path.basename(file)

        case extract_imports(source, filename) do
          {:ok, imports} -> Enum.filter(imports, &bare_specifier?/1)
          {:error, _} -> []
        end
      end)

    {:ok, specifiers}
  end

  defp extract_imports(source, filename) do
    ext = Path.extname(filename)

    if ext == ".vue" do
      extract_vue_imports(source)
    else
      OXC.imports(source, filename)
    end
  end

  defp extract_vue_imports(source), do: Volt.VueImports.extract(source)

  defp bare_specifier?(spec) do
    not String.starts_with?(spec, ".") and
      not String.starts_with?(spec, "/") and
      not String.contains?(spec, "://")
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
        source = File.read!(entry_path)
        filename = Path.basename(entry_path)
        files = [{filename, source}]

        case OXC.bundle(files) do
          {:ok, code} when is_binary(code) ->
            File.write!(output_path, code)
            {:ok, output_path}

          {:ok, %{code: code}} ->
            File.write!(output_path, code)
            {:ok, output_path}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp resolve_package_entry(specifier, node_modules) when is_binary(node_modules) do
    {package_name, subpath} = PackageResolver.split_specifier(specifier)
    package_dir = Path.join(node_modules, package_name)

    if subpath do
      try_resolve(Path.join(package_dir, subpath))
    else
      PackageResolver.resolve_package_entry(package_dir, package_name, &try_resolve/1)
    end
  end

  defp resolve_package_entry(_specifier, nil) do
    {:error, :no_node_modules}
  end

  @extensions ["", ".ts", ".tsx", ".js", ".jsx", ".mjs"]

  defp try_resolve(base) do
    Enum.find_value(@extensions, fn ext ->
      path = base <> ext
      if File.regular?(path), do: {:ok, path}
    end) || {:error, {:not_found, base}}
  end

  defp ensure_cache_dir do
    File.mkdir_p!(@cache_dir)
    :ok
  end

  defp cache_path(specifier) do
    Path.join(@cache_dir, encode_specifier(specifier) <> ".js")
  end

  @doc false
  def encode_specifier(specifier) do
    specifier
    |> String.replace("@", "__at__")
    |> String.replace("/", "__slash__")
  end

  @doc false
  def decode_specifier(encoded) do
    encoded
    |> String.replace("__slash__", "/")
    |> String.replace("__at__", "@")
  end
end
