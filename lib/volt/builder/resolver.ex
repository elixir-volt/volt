defmodule Volt.Builder.Resolver do
  @moduledoc "Resolve import specifiers to absolute file paths for the build graph."

  @doc """
  Resolve an import specifier to an absolute file path.

  Returns `{:ok, path}`, `:skip` (for externals/node builtins), or `{:error, reason}`.
  """
  def resolve(specifier, importer, ctx) do
    if external?(specifier, ctx.external) do
      :skip
    else
      case Volt.PluginRunner.resolve(ctx.plugins, specifier, importer) do
        {:ok, _} = resolved ->
          resolved

        nil ->
          case Volt.JS.Resolver.resolve(specifier, ctx.aliases) do
            {:ok, aliased} ->
              case NPM.PackageResolver.try_resolve(Path.expand(aliased),
                     extensions: Volt.JS.Extensions.resolvable()
                   ) do
                {:ok, _} = ok -> ok
                :error -> {:error, {:not_found, aliased}}
              end

            :pass ->
              resolve_by_type(specifier, importer, ctx)
          end
      end
    end
  end

  def absolute?(specifier), do: String.starts_with?(specifier, "/")

  defp resolve_by_type(specifier, importer, ctx) do
    cond do
      NPM.PackageResolver.node_builtin?(specifier) ->
        :skip

      NPM.PackageResolver.relative?(specifier) ->
        base = Path.expand(specifier, Path.dirname(importer))

        case NPM.PackageResolver.try_resolve(base, extensions: Volt.JS.Extensions.resolvable()) do
          {:ok, _} = ok ->
            ok

          :error ->
            if File.exists?(base <> ".d.ts") or File.exists?(base <> ".d.cts") or
                 File.exists?(base <> ".d.mts"),
               do: :skip,
               else: {:error, {:not_found, base}}
        end

      true ->
        resolve_bare(specifier, ctx.node_modules, ctx.resolve_dirs)
    end
  end

  defp external?(specifier, external) do
    MapSet.member?(external, specifier) or
      Enum.any?(external, &String.starts_with?(specifier, &1 <> "/"))
  end

  defp resolve_bare(specifier, node_modules, resolve_dirs) do
    dirs = if node_modules, do: [node_modules | resolve_dirs], else: resolve_dirs

    Enum.find_value(dirs, :skip, fn dir ->
      {package_name, _subpath} = NPM.PackageResolver.split_specifier(specifier)
      package_dir = Path.join(dir, package_name)

      if File.dir?(package_dir) do
        resolve_in_package(specifier, dir, package_dir)
      end
    end)
  end

  defp resolve_in_package(specifier, dir, package_dir) do
    subpath = subpath_for(specifier)
    extensions = Volt.JS.Extensions.resolvable()

    case NPM.PackageResolver.resolve_entry(package_dir, subpath: subpath, extensions: extensions) do
      {:ok, resolved} ->
        if subpath != "." and resolved == resolve_main(package_dir) do
          case NPM.PackageResolver.try_resolve(Path.join(dir, specifier), extensions: extensions) do
            {:ok, _} = ok -> ok
            :error -> {:ok, resolved}
          end
        else
          {:ok, resolved}
        end

      :error ->
        nil
    end
  end

  defp resolve_main(package_dir) do
    case NPM.PackageResolver.resolve_entry(package_dir,
           subpath: ".",
           extensions: Volt.JS.Extensions.resolvable()
         ) do
      {:ok, path} -> path
      :error -> nil
    end
  end

  defp subpath_for(specifier) do
    case NPM.PackageResolver.split_specifier(specifier) do
      {_, nil} -> "."
      {_, subpath} -> subpath
    end
  end
end
