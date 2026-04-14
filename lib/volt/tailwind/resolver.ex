defmodule Volt.Tailwind.Resolver do
  @moduledoc "Resolves stylesheet and module paths for the Tailwind runtime."

  @module_extensions ["", ".js", ".cjs", ".json"]
  @module_index_files ["/index.js", "/index.cjs", "/index.json"]
  @stylesheet_extensions ["", ".css"]
  @stylesheet_index_files ["/index.css"]
  @cjs_conditions ["require", "default", "browser", "import"]

  def resolve_stylesheet_path!(id, base) do
    base = normalize_base(base)

    if NPM.PackageResolver.relative?(id) or absolute?(id) do
      resolve_path!(base, id, @stylesheet_extensions, @stylesheet_index_files)
    else
      resolve_bare_path!(id, base, @stylesheet_extensions, @stylesheet_index_files, "stylesheet")
    end
  end

  def resolve_module_path!(id, base, kind) do
    base = normalize_base(base)

    if NPM.PackageResolver.relative?(id) or absolute?(id) do
      resolve_path!(base, id, @module_extensions, @module_index_files)
    else
      resolve_bare_path!(id, base, @module_extensions, @module_index_files, kind)
    end
  end

  def node_builtin_specifier?(specifier), do: NPM.PackageResolver.node_builtin?(specifier)
  def relative_specifier?(specifier), do: NPM.PackageResolver.relative?(specifier)
  def absolute_specifier?(specifier), do: absolute?(specifier)

  defp absolute?(id), do: Volt.Builder.Resolver.absolute?(id)

  defp resolve_bare_path!(id, base, extensions, index_files, kind) do
    {package_name, subpath} = NPM.PackageResolver.split_specifier(id)

    resolved =
      [find_node_modules_for(base), installed_node_modules_dir()]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.find_value(fn node_modules ->
        package_dir = Path.join(node_modules, package_name)

        result =
          if subpath do
            resolve_package_subpath(package_dir, subpath, extensions, index_files)
          else
            resolve_package_entry(package_dir, extensions, index_files)
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

  defp resolve_package_entry(package_dir, extensions, index_files) do
    case NPM.PackageResolver.resolve_entry(package_dir, conditions: @cjs_conditions) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_resolve(Path.join(package_dir, "index"), extensions, index_files)
    end
  end

  defp resolve_package_subpath(package_dir, subpath, extensions, index_files) do
    case NPM.PackageResolver.resolve_entry(package_dir,
           subpath: subpath,
           conditions: @cjs_conditions
         ) do
      {:ok, _} = ok ->
        ok

      :error ->
        subpath_bare = String.trim_leading(subpath, "./")
        try_resolve(Path.join(package_dir, subpath_bare), extensions, index_files)
    end
  end

  defp resolve_path!(base, id, extensions, index_files) do
    target = if absolute?(id), do: Path.expand(id), else: Path.expand(id, base)

    case try_resolve(target, extensions, index_files) do
      {:ok, path} ->
        path

      {:error, reason} ->
        raise "Could not resolve file #{inspect(id)} from #{inspect(base)}: #{inspect(reason)}"
    end
  end

  defp try_resolve(base, extensions, index_files) do
    Enum.find_value(extensions, fn ext ->
      path = base <> ext
      if File.regular?(path), do: {:ok, path}
    end) ||
      Enum.find_value(index_files, fn index ->
        path = base <> index
        if File.regular?(path), do: {:ok, path}
      end) || {:error, :not_found}
  end

  def normalize_base(base) when base in [nil, "", "."], do: File.cwd!()
  def normalize_base(base), do: Path.expand(base)

  defp find_node_modules_for(base) do
    base |> normalize_base() |> NPM.PackageResolver.find_node_modules()
  end

  defp installed_node_modules_dir, do: NPM.node_modules_dir!()
end
