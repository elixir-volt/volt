defmodule Volt.JS.Package do
  @moduledoc false

  @doc """
  The real directories of the packages in `node_modules` that are links to
  somewhere outside it, such as path dependencies and `npm link`ed packages.

  Their files change in place, unlike installed packages, which change only
  with the lockfile.
  """
  @spec linked_dirs(Path.t() | nil) :: [Path.t()]
  def linked_dirs(nil), do: []

  def linked_dirs(node_modules) do
    node_modules = Path.expand(node_modules)

    node_modules
    |> package_dirs()
    |> Enum.flat_map(fn dir ->
      with {:ok, %File.Stat{type: :symlink}} <- File.lstat(dir),
           {:ok, target} <- File.read_link(dir),
           real = Path.expand(target, Path.dirname(dir)),
           false <- Volt.Path.inside?(real, node_modules) do
        [real]
      else
        _installed_or_unreadable -> []
      end
    end)
    |> Enum.uniq()
  end

  defp package_dirs(node_modules) do
    node_modules
    |> entries()
    |> Enum.flat_map(fn
      "@" <> _ = scope ->
        scope_dir = Path.join(node_modules, scope)
        scope_dir |> entries() |> Enum.map(&Path.join(scope_dir, &1))

      name ->
        [Path.join(node_modules, name)]
    end)
  end

  defp entries(dir) do
    case File.ls(dir) do
      {:ok, names} -> Enum.reject(names, &String.starts_with?(&1, "."))
      {:error, _reason} -> []
    end
  end

  def subpath_for(specifier) do
    case NPM.Resolution.PackageResolver.split_specifier(specifier) do
      {_, nil} -> "."
      {_, subpath} -> subpath
    end
  end
end
