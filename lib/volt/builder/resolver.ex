defmodule Volt.Builder.Resolver do
  @moduledoc "Resolve import specifiers to absolute file paths for the build graph."

  @doc """
  Resolve an import specifier to an absolute file path.

  Returns `{:ok, path}`, `:skip` (for externals/node builtins), or `{:error, reason}`.
  """
  def resolve(specifier, importer, ctx) do
    {path_specifier, query} = Volt.JS.Specifier.split_query(specifier)

    if external?(path_specifier, ctx.external) do
      :skip
    else
      do_resolve(path_specifier, importer, ctx, query)
    end
  end

  def absolute?(specifier), do: String.starts_with?(specifier, "/")

  defp do_resolve(specifier, importer, ctx, query) do
    case Volt.PluginRunner.resolve(ctx.plugins, specifier, importer) do
      {:ok, resolved} -> {:ok, Volt.URL.append_query(resolved, query)}
      nil -> resolve_specifier(specifier, importer, ctx, query)
    end
  end

  defp resolve_specifier(specifier, importer, ctx, query) do
    case Volt.JS.Resolver.resolve(specifier, ctx.aliases) do
      {:ok, aliased} -> append_query(resolve_aliased(aliased, ctx), query)
      :pass -> append_query(resolve_by_type(specifier, importer, ctx), query)
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

  defp append_query({:ok, path}, query), do: {:ok, Volt.URL.append_query(path, query)}
  defp append_query(other, _query), do: other

  defp resolve_by_type(specifier, importer, ctx) do
    cond do
      NPM.Resolution.PackageResolver.node_builtin?(specifier) ->
        :skip

      absolute?(specifier) ->
        resolve_absolute(specifier)

      String.starts_with?(specifier, "#") ->
        resolve_package_import(specifier, importer, ctx)

      NPM.Resolution.PackageResolver.relative?(specifier) ->
        resolve_relative(specifier, importer, ctx)

      true ->
        resolve_bare(specifier, importer, ctx)
    end
  end

  defp resolve_absolute(specifier) do
    if File.exists?(specifier) do
      {:ok, specifier}
    else
      {:error, {:not_found, specifier}}
    end
  end

  @js_to_ts_map %{".js" => [".ts", ".tsx"], ".jsx" => [".tsx"], ".mjs" => [".mts"]}

  defp resolve_package_import(specifier, importer, ctx) do
    {importer_path, _query} = Volt.URL.split_query(importer)

    case NPM.Resolution.PackageResolver.resolve(specifier, Path.dirname(importer_path),
           extensions: Volt.JS.Extensions.resolvable(ctx.plugins),
           conditions: Volt.JS.Resolution.browser_conditions()
         ) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:not_found, specifier}}
      {:builtin, _} -> :skip
    end
  end

  defp resolve_relative(specifier, importer, ctx) do
    {importer_path, _query} = Volt.URL.split_query(importer)
    base = Path.expand(specifier, Path.dirname(importer_path))

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

  defp external?(specifier, external) do
    MapSet.member?(external, specifier) or
      Enum.any?(external, &String.starts_with?(specifier, &1 <> "/"))
  end

  defp scoped_package_dirs(nil, _scopes), do: []

  defp scoped_package_dirs(importer, scopes) do
    {importer_path, _query} = Volt.URL.split_query(importer)
    importer_path = Path.expand(importer_path)

    for {source_root, package_dir} <- scopes,
        path_within?(importer_path, source_root) or path_within?(importer_path, package_dir),
        do: package_dir
  end

  defp path_within?(path, root) do
    relative = Path.relative_to(path, root)
    Path.type(relative) == :relative and not match?([".." | _rest], Path.split(relative))
  end

  defp resolve_bare(specifier, importer, ctx) do
    global_dirs =
      if ctx.node_modules, do: [ctx.node_modules | ctx.resolve_dirs], else: ctx.resolve_dirs

    dirs =
      importer
      |> scoped_package_dirs(ctx.package_scopes)
      |> Kernel.++(global_dirs)
      |> Enum.uniq()

    case Enum.find_value(dirs, fn dir ->
           {package_name, _subpath} = NPM.Resolution.PackageResolver.split_specifier(specifier)
           package_dir = Path.join(dir, package_name)

           if File.dir?(package_dir) do
             resolve_in_package(specifier, dir, package_dir, ctx.plugins) || :unresolved_package
           end
         end) do
      nil -> :skip
      :unresolved_package -> {:error, {:not_found, specifier}}
      result -> result
    end
  end

  defp resolve_in_package(specifier, dir, package_dir, plugins) do
    subpath = Volt.JS.Package.subpath_for(specifier)
    extensions = Volt.JS.Extensions.resolvable(plugins)

    case NPM.Resolution.PackageResolver.resolve_entry(package_dir,
           subpath: subpath,
           extensions: extensions,
           conditions: Volt.JS.Resolution.browser_conditions()
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
           conditions: Volt.JS.Resolution.browser_conditions()
         ) do
      {:ok, path} -> path
      :error -> nil
    end
  end
end
