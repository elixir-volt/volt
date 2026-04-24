defmodule Volt.JS.PackageResolver do
  @moduledoc false

  @default_extensions Volt.JS.Extensions.node_resolvable()
  @conditions ["import", "browser", "default", "module", "require"]

  def resolve(specifier, from_dir, opts \\ []) do
    do_resolve(specifier, from_dir, opts)
  end

  def relative_import_path(importer, target, project_root) do
    NPM.PackageResolver.relative_import_path(importer, target, project_root)
  end

  def relative?(specifier), do: NPM.PackageResolver.relative?(specifier)

  defp do_resolve(specifier, from_dir, opts) do
    cond do
      NPM.PackageResolver.node_builtin?(specifier) ->
        {:builtin, specifier}

      String.starts_with?(specifier, "#") ->
        resolve_import(specifier, from_dir, opts)

      NPM.PackageResolver.relative?(specifier) ->
        base = Path.expand(specifier, from_dir)
        try_resolve(base, extensions(opts))

      true ->
        resolve_bare(specifier, from_dir, opts)
    end
  end

  defp resolve_import(specifier, from_dir, opts) do
    with {:ok, package_dir, package} <- nearest_package(from_dir),
         %{} = imports <- Map.get(package, "imports") do
      imports
      |> export_candidates(specifier)
      |> Enum.find_value(:error, fn target ->
        resolve_target(package_dir, target, extensions(opts))
      end)
    else
      _ -> :error
    end
  end

  defp nearest_package(dir) do
    package_json = Path.join(dir, "package.json")

    cond do
      File.regular?(package_json) ->
        with {:ok, package} <- read_json(package_json), do: {:ok, dir, package}

      dir == "/" or Path.basename(dir) == "node_modules" ->
        :error

      true ->
        nearest_package(Path.dirname(dir))
    end
  end

  defp resolve_bare(specifier, from_dir, opts) do
    {package_name, subpath} = NPM.PackageResolver.split_specifier(specifier)

    case NPM.PackageResolver.find_node_modules(from_dir) do
      nil ->
        :error

      node_modules ->
        package_dir = Path.join(node_modules, package_name)

        if File.dir?(package_dir) do
          resolve_package(package_dir, subpath || ".", opts)
        else
          :error
        end
    end
  end

  defp resolve_package(package_dir, subpath, opts) do
    extensions = extensions(opts)
    package_json_path = Path.join(package_dir, "package.json")

    with {:ok, package} <- read_json(package_json_path),
         :error <- resolve_exports(package, package_dir, subpath, extensions, conditions(opts)) do
      resolve_fields(package, package_dir, subpath, extensions)
    else
      {:ok, _} = ok -> ok
      _ -> try_resolve(Path.join(package_dir, "index"), extensions)
    end
  end

  defp resolve_exports(%{"exports" => exports}, package_dir, subpath, extensions, conditions) do
    exports = normalize_exports(exports)

    exports
    |> export_candidates(subpath, conditions)
    |> Enum.find_value(:error, fn target ->
      resolve_target(package_dir, target, extensions)
    end)
  end

  defp resolve_exports(_, _, _, _, _), do: :error

  defp normalize_exports(exports) when is_binary(exports), do: %{"." => exports}

  defp normalize_exports(exports) when is_map(exports) do
    if Enum.any?(Map.keys(exports), &String.starts_with?(&1, ".")) do
      exports
    else
      %{"." => exports}
    end
  end

  defp normalize_exports(_), do: %{}

  defp export_candidates(exports, subpath, conditions \\ @conditions) do
    exact = Map.get(exports, subpath) |> flatten_conditions(conditions)

    wildcard =
      exports
      |> Enum.flat_map(fn {pattern, target} ->
        case wildcard_replacement(pattern, subpath) do
          nil ->
            []

          replacement ->
            Enum.map(
              flatten_conditions(target, conditions),
              &String.replace(&1, "*", replacement)
            )
        end
      end)

    exact ++ wildcard
  end

  defp flatten_conditions(nil, _conditions), do: []
  defp flatten_conditions(path, _conditions) when is_binary(path), do: [path]

  defp flatten_conditions(list, conditions) when is_list(list),
    do: Enum.flat_map(list, &flatten_conditions(&1, conditions))

  defp flatten_conditions(map, conditions) when is_map(map) do
    conditions
    |> Enum.flat_map(fn condition ->
      Map.get(map, condition) |> flatten_conditions(conditions)
    end)
  end

  defp wildcard_replacement(pattern, subpath) do
    case String.split(pattern, "*", parts: 2) do
      [prefix, suffix] ->
        if String.starts_with?(subpath, prefix) and String.ends_with?(subpath, suffix) do
          subpath
          |> String.trim_leading(prefix)
          |> trim_suffix(suffix)
        end

      _ ->
        nil
    end
  end

  defp trim_suffix(value, ""), do: value
  defp trim_suffix(value, suffix), do: String.trim_trailing(value, suffix)

  defp resolve_target(package_dir, "./" <> _ = target, extensions) do
    Path.join(package_dir, String.trim_leading(target, "./"))
    |> try_resolve(extensions)
    |> ok_or_nil()
  end

  defp resolve_target(package_dir, target, extensions) when is_binary(target) do
    Path.join(package_dir, target)
    |> try_resolve(extensions)
    |> ok_or_nil()
  end

  defp resolve_fields(_package, _package_dir, subpath, _extensions) when subpath != ".",
    do: :error

  defp resolve_fields(package, package_dir, ".", extensions) do
    ["module", "browser", "main"]
    |> Enum.find_value(:error, fn field ->
      case Map.get(package, field) do
        path when is_binary(path) ->
          package_dir |> Path.join(path) |> try_resolve(extensions) |> ok_or_nil()

        _ ->
          nil
      end
    end)
  end

  defp try_resolve(path, extensions) do
    cond do
      File.regular?(path) ->
        {:ok, path}

      match = Enum.find(extensions, &File.regular?(path <> &1)) ->
        {:ok, path <> match}

      true ->
        Enum.find_value(extensions, :error, fn ext ->
          index = Path.join(path, "index" <> ext)
          if File.regular?(index), do: {:ok, index}
        end)
    end
  end

  defp ok_or_nil({:ok, _} = ok), do: ok
  defp ok_or_nil(:error), do: nil

  defp read_json(path) do
    with {:ok, source} <- File.read(path), {:ok, json} <- Jason.decode(source), do: {:ok, json}
  end

  defp extensions(opts), do: Keyword.get(opts, :extensions, @default_extensions)
  defp conditions(opts), do: Keyword.get(opts, :conditions, @conditions)
end
