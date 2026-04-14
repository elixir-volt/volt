defmodule Volt.Tailwind.Resolver do
  @moduledoc "Resolves stylesheet and module paths for the Tailwind runtime."

  alias Volt.Builder.Resolver, as: BaseResolver
  alias Volt.PackageResolver

  @module_extensions ["", ".js", ".cjs", ".json"]
  @module_index_files ["/index.js", "/index.cjs", "/index.json"]
  @stylesheet_extensions ["", ".css"]
  @stylesheet_index_files ["/index.css"]
  @cjs_order PackageResolver.cjs_condition_order()

  def resolve_stylesheet_path!(id, base) do
    base = normalize_base(base)

    if BaseResolver.relative?(id) or BaseResolver.absolute?(id) do
      resolve_path!(base, id, @stylesheet_extensions, @stylesheet_index_files)
    else
      resolve_bare_path!(id, base, @stylesheet_extensions, @stylesheet_index_files, "stylesheet")
    end
  end

  def resolve_module_path!(id, base, kind) do
    base = normalize_base(base)

    if BaseResolver.relative?(id) or BaseResolver.absolute?(id) do
      resolve_path!(base, id, @module_extensions, @module_index_files)
    else
      resolve_bare_path!(id, base, @module_extensions, @module_index_files, kind)
    end
  end

  def node_builtin_specifier?(specifier), do: BaseResolver.node_builtin?(specifier)
  def relative_specifier?(specifier), do: BaseResolver.relative?(specifier)
  def absolute_specifier?(specifier), do: BaseResolver.absolute?(specifier)

  defp resolve_bare_path!(id, base, extensions, index_files, kind) do
    {package_name, subpath} = PackageResolver.split_specifier(id)

    resolved =
      [find_node_modules_for(base), installed_node_modules_dir()]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.find_value(fn node_modules ->
        package_dir = Path.join(node_modules, package_name)

        result =
          if subpath do
            resolve_package_subpath(package_dir, package_name, subpath, extensions, index_files)
          else
            resolve_package_entry(package_dir, package_name, extensions, index_files)
          end

        case result do
          {:ok, path} -> {:ok, path}
          _ -> nil
        end
      end)

    case resolved do
      {:ok, path} ->
        path

      nil ->
        raise "Could not resolve #{kind} #{inspect(id)} from #{inspect(base)}. Add it to node_modules or the Tailwind runtime install."
    end
  end

  defp resolve_package_entry(package_dir, package_name, extensions, index_files) do
    with {:ok, package} <- read_package(package_dir, package_name) do
      entry =
        PackageResolver.resolve_export(package, ".", @cjs_order) ||
          package["browser"] ||
          package["main"] ||
          package["module"] ||
          "index.js"

      BaseResolver.try_resolve(
        Path.expand(Path.join(package_dir, entry)),
        extensions,
        index_files
      )
    end
  end

  defp resolve_package_subpath(package_dir, package_name, subpath, extensions, index_files) do
    with {:ok, package} <- read_package(package_dir, package_name) do
      case PackageResolver.resolve_export(package, "./#{subpath}", @cjs_order) do
        nil ->
          BaseResolver.try_resolve(Path.join(package_dir, subpath), extensions, index_files)

        entry ->
          BaseResolver.try_resolve(
            Path.expand(Path.join(package_dir, entry)),
            extensions,
            index_files
          )
      end
    end
  end

  defp read_package(package_dir, package_name) do
    package_json = Path.join(package_dir, "package.json")

    with {:ok, content} <- File.read(package_json),
         {:ok, package} <- Jason.decode(content) do
      {:ok, package}
    else
      {:error, reason} ->
        {:error, {:package_resolution_failed, package_name, reason}}
    end
  end

  defp resolve_path!(base, id, extensions, index_files) do
    target = if BaseResolver.absolute?(id), do: Path.expand(id), else: Path.expand(id, base)

    case BaseResolver.try_resolve(target, extensions, index_files) do
      {:ok, path} ->
        path

      {:error, reason} ->
        raise "Could not resolve file #{inspect(id)} from #{inspect(base)}: #{inspect(reason)}"
    end
  end

  def normalize_base(base) when base in [nil, "", "."], do: File.cwd!()
  def normalize_base(base), do: Path.expand(base)

  defp find_node_modules_for(base) do
    base |> normalize_base() |> PackageResolver.find_node_modules()
  end

  defp installed_node_modules_dir, do: NPM.node_modules_dir!()
end
