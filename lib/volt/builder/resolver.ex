defmodule Volt.Builder.Resolver do
  @moduledoc "Resolve import specifiers to absolute file paths for the build graph."

  alias Volt.PackageResolver

  @node_builtin_specifiers ~w(
    assert buffer child_process crypto events fs http https
    os path stream tty url util zlib
  )

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
          case Volt.Resolver.resolve(specifier, ctx.aliases) do
            {:ok, aliased} -> try_resolve(Path.expand(aliased))
            :pass -> resolve_by_type(specifier, importer, ctx)
          end
      end
    end
  end

  defp resolve_by_type(specifier, importer, ctx) do
    cond do
      node_builtin?(specifier) -> :skip
      relative?(specifier) -> resolve_relative(specifier, importer)
      true -> resolve_bare(specifier, ctx.node_modules, ctx.resolve_dirs)
    end
  end

  def relative?(specifier) do
    String.starts_with?(specifier, "./") or String.starts_with?(specifier, "../")
  end

  def absolute?(specifier), do: String.starts_with?(specifier, "/")

  def bare?(specifier) do
    not relative?(specifier) and not absolute?(specifier) and
      not String.contains?(specifier, "://")
  end

  def node_builtin?(specifier) do
    specifier in @node_builtin_specifiers or String.starts_with?(specifier, "node:")
  end

  def try_resolve(
        base,
        extensions \\ Volt.Extensions.resolvable(),
        index_files \\ Volt.Extensions.resolvable_index()
      ) do
    Enum.find_value(extensions, fn ext ->
      path = base <> ext
      if File.regular?(path), do: {:ok, path}
    end) ||
      Enum.find_value(index_files, fn idx ->
        path = base <> idx
        if File.regular?(path), do: {:ok, path}
      end) ||
      {:error, {:not_found, base}}
  end

  defp external?(specifier, external) do
    MapSet.member?(external, specifier) or
      Enum.any?(external, &String.starts_with?(specifier, &1 <> "/"))
  end

  defp resolve_relative(specifier, importer) do
    base = Path.join(Path.dirname(importer), specifier) |> Path.expand()
    try_resolve(base)
  end

  defp resolve_bare(specifier, node_modules, resolve_dirs) do
    dirs = if node_modules, do: [node_modules | resolve_dirs], else: resolve_dirs

    Enum.find_value(dirs, :skip, fn dir ->
      case resolve_in_dir(specifier, dir) do
        {:ok, _} = found -> found
        _ -> nil
      end
    end)
  end

  defp resolve_in_dir(specifier, dir) do
    {package_name, subpath} = PackageResolver.split_specifier(specifier)
    package_dir = Path.join(dir, package_name)

    if subpath do
      try_resolve(Path.join(package_dir, subpath))
    else
      PackageResolver.resolve_package_entry(package_dir, package_name, &try_resolve/1)
    end
  end
end
