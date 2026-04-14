defmodule Volt.PackageResolver do
  @moduledoc false

  @browser_condition_order ["browser", "import", "default", "require"]
  @cjs_condition_order ["require", "default", "browser", "import"]

  def split_specifier("@" <> rest) do
    case String.split(rest, "/", parts: 3) do
      [scope, name, subpath] -> {"@#{scope}/#{name}", subpath}
      [scope, name] -> {"@#{scope}/#{name}", nil}
      _ -> {"@#{rest}", nil}
    end
  end

  def split_specifier(specifier) do
    case String.split(specifier, "/", parts: 2) do
      [name, subpath] -> {name, subpath}
      [name] -> {name, nil}
    end
  end

  def resolve_package_entry(package_dir, package_name, try_resolve) do
    pkg_json = Path.join(package_dir, "package.json")

    case File.read(pkg_json) do
      {:ok, content} ->
        pkg = :json.decode(content)

        entry =
          resolve_exports(pkg) ||
            pkg["browser"] ||
            pkg["module"] ||
            pkg["main"] ||
            "index.js"

        try_resolve.(Path.expand(Path.join(package_dir, entry)))

      {:error, _} ->
        {:error, {:not_found, package_name}}
    end
  end

  def resolve_exports(pkg), do: resolve_export(pkg, ".", @browser_condition_order)

  def resolve_export(%{"exports" => exports}, ".", _order) when is_binary(exports), do: exports

  def resolve_export(%{"exports" => exports}, key, order) when is_map(exports) do
    resolve_condition(exports[key], order)
  end

  def resolve_export(_, _, _), do: nil

  def resolve_condition(value, _order) when is_binary(value), do: value

  def resolve_condition(%{} = conditions, order) do
    Enum.find_value(order, fn key -> conditions[key] end)
    |> then(fn
      nil -> nil
      nested -> resolve_condition(nested, order)
    end)
  end

  def resolve_condition(_, _), do: nil

  def browser_condition_order, do: @browser_condition_order
  def cjs_condition_order, do: @cjs_condition_order

  def find_node_modules(dir) do
    candidate = Path.join(dir, "node_modules")

    cond do
      File.dir?(candidate) -> candidate
      dir == "/" -> nil
      true -> find_node_modules(Path.dirname(dir))
    end
  end
end
