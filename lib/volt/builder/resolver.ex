defmodule Volt.Builder.Resolver do
  @moduledoc "Resolve import specifiers to absolute file paths for the build graph."

  @doc """
  Resolve an import specifier to an absolute file path.

  Returns `{:ok, path}`, `:skip` (for externals/node builtins), or `{:error, reason}`.
  """
  def resolve(specifier, importer, ctx) do
    cond do
      external?(specifier, ctx.external) -> :skip
      css_specifier?(specifier) -> :skip
      true -> do_resolve(specifier, importer, ctx)
    end
  end

  def absolute?(specifier), do: String.starts_with?(specifier, "/")

  defp do_resolve(specifier, importer, ctx) do
    case Volt.PluginRunner.resolve(ctx.plugins, specifier, importer) do
      {:ok, _} = resolved -> resolved
      nil -> resolve_specifier(specifier, importer, ctx)
    end
  end

  defp resolve_specifier(specifier, importer, ctx) do
    case Volt.JS.Resolver.resolve(specifier, ctx.aliases) do
      {:ok, aliased} -> resolve_aliased(aliased, ctx)
      :pass -> resolve_by_type(specifier, importer, ctx)
    end
  end

  defp resolve_aliased(aliased, ctx) do
    case NPM.Resolution.PackageResolver.try_resolve(Path.expand(aliased),
           extensions: Volt.JS.Extensions.resolvable(ctx.plugins)
         ) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:not_found, aliased}}
    end
  end

  defp resolve_by_type(specifier, importer, ctx) do
    cond do
      NPM.Resolution.PackageResolver.node_builtin?(specifier) ->
        :skip

      String.starts_with?(specifier, "#") ->
        resolve_package_import(specifier, importer, ctx)

      NPM.Resolution.PackageResolver.relative?(specifier) ->
        resolve_relative(specifier, importer, ctx)

      true ->
        resolve_bare(specifier, ctx.node_modules, ctx.resolve_dirs, ctx.plugins)
    end
  end

  @js_to_ts_map %{".js" => [".ts", ".tsx"], ".jsx" => [".tsx"], ".mjs" => [".mts"]}

  defp resolve_package_import(specifier, importer, ctx) do
    case Volt.JS.PackageResolver.resolve(specifier, Path.dirname(importer),
           extensions: Volt.JS.Extensions.resolvable(ctx.plugins)
         ) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:not_found, specifier}}
      {:builtin, _} -> :skip
    end
  end

  defp resolve_relative(specifier, importer, ctx) do
    base = Path.expand(specifier, Path.dirname(importer))

    case NPM.Resolution.PackageResolver.try_resolve(base,
           extensions: Volt.JS.Extensions.resolvable(ctx.plugins)
         ) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_ts_extension(base) ||
          if(type_declaration?(base), do: :skip, else: {:error, {:not_found, base}})
    end
  end

  defp try_ts_extension(base) do
    ext = Path.extname(base)

    case Map.get(@js_to_ts_map, ext) do
      nil ->
        nil

      ts_exts ->
        root = Path.rootname(base)

        Enum.find_value(ts_exts, fn ts_ext ->
          path = root <> ts_ext
          if File.regular?(path), do: {:ok, path}
        end)
    end
  end

  defp type_declaration?(base) do
    File.exists?(base <> ".d.ts") or File.exists?(base <> ".d.cts") or
      File.exists?(base <> ".d.mts")
  end

  defp css_specifier?(specifier) do
    Path.extname(specifier) in Volt.JS.Extensions.css()
  end

  defp external?(specifier, external) do
    MapSet.member?(external, specifier) or
      Enum.any?(external, &String.starts_with?(specifier, &1 <> "/"))
  end

  defp resolve_bare(specifier, node_modules, resolve_dirs, plugins) do
    dirs = if node_modules, do: [node_modules | resolve_dirs], else: resolve_dirs

    Enum.find_value(dirs, :skip, fn dir ->
      {package_name, _subpath} = NPM.Resolution.PackageResolver.split_specifier(specifier)
      package_dir = Path.join(dir, package_name)

      if File.dir?(package_dir) do
        resolve_in_package(specifier, dir, package_dir, plugins)
      end
    end)
  end

  defp resolve_in_package(specifier, dir, package_dir, plugins) do
    subpath = subpath_for(specifier)
    extensions = Volt.JS.Extensions.resolvable(plugins)

    case NPM.Resolution.PackageResolver.resolve_entry(package_dir,
           subpath: subpath,
           extensions: extensions,
           conditions: Volt.JS.PackageResolver.browser_conditions()
         ) do
      {:ok, resolved} ->
        maybe_try_direct_path(resolved, subpath, dir, specifier, package_dir, extensions)

      :error ->
        case NPM.Resolution.PackageResolver.try_resolve(Path.join(dir, specifier),
               extensions: extensions
             ) do
          {:ok, _} = ok -> ok
          :error -> nil
        end
    end
  end

  defp maybe_try_direct_path(resolved, ".", _dir, _specifier, _package_dir, _extensions),
    do: {:ok, resolved}

  defp maybe_try_direct_path(resolved, _subpath, dir, specifier, package_dir, extensions) do
    main = resolve_main(package_dir, extensions)

    if resolved == main do
      case NPM.Resolution.PackageResolver.try_resolve(Path.join(dir, specifier),
             extensions: extensions
           ) do
        {:ok, _} = ok -> ok
        :error -> {:ok, resolved}
      end
    else
      {:ok, resolved}
    end
  end

  defp resolve_main(package_dir, extensions) do
    case NPM.Resolution.PackageResolver.resolve_entry(package_dir,
           subpath: ".",
           extensions: extensions,
           conditions: Volt.JS.PackageResolver.browser_conditions()
         ) do
      {:ok, path} -> path
      :error -> nil
    end
  end

  defp subpath_for(specifier) do
    case NPM.Resolution.PackageResolver.split_specifier(specifier) do
      {_, nil} -> "."
      {_, subpath} -> subpath
    end
  end
end
