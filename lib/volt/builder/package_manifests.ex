defmodule Volt.Builder.PackageManifests do
  @moduledoc """
  Carries the `sideEffects` field of bundled packages into the bundle input.

  Modules are bundled from a virtual project in which a package's files sit
  under the package name (see `Volt.Builder.Naming.module_label/2`), without
  the package's `package.json`. Rolldown reads `sideEffects` from the nearest
  `package.json`, so without one it keeps every module that runs code at the
  top level, such as each icon of an icon library wrapped in `forwardRef`. A
  minimal manifest at the package root restores what the package declared.
  """

  @doc """
  Returns a `{label, json}` virtual file for each package of `modules` whose
  `package.json` declares `sideEffects`.
  """
  @spec files([{String.t(), String.t(), term()}]) :: [{String.t(), String.t()}]
  def files(modules) do
    modules
    |> Enum.flat_map(fn {path, _label, _source} -> package_root(path) end)
    |> Enum.uniq()
    |> Enum.flat_map(&manifest_file/1)
  end

  defp package_root(module_id) do
    {path, _query} = Volt.URL.split_query(module_id)

    case path |> :binary.matches("/node_modules/") |> List.last() do
      nil ->
        []

      {position, length} ->
        root_end = position + length
        name = package_name(binary_part(path, root_end, byte_size(path) - root_end))
        [{name, binary_part(path, 0, root_end) <> name}]
    end
  end

  defp package_name("@" <> _ = relative_path),
    do: relative_path |> String.split("/") |> Enum.take(2) |> Enum.join("/")

  defp package_name(relative_path), do: relative_path |> String.split("/") |> hd()

  defp manifest_file({name, dir}) do
    with {:ok, json} <- File.read(Path.join(dir, "package.json")),
         {:ok, %{"sideEffects" => side_effects}} <- Jason.decode(json) do
      manifest = Jason.encode!(%{"sideEffects" => side_effects})
      [{Volt.Builder.Naming.file_path(name) <> "/package.json", manifest}]
    else
      _ -> []
    end
  end
end
