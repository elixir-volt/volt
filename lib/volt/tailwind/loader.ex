defmodule Volt.Tailwind.Loader do
  @moduledoc "Handles Tailwind module loading, prebundling CJS graphs via OXC, and stylesheet resolution."

  alias Volt.JS.Runtime.PackageSet
  alias Volt.JS.Transforms.Specifiers
  alias Volt.Tailwind.Resolver

  @tailwind_runtime_deps %{
    "tailwindcss" => "4.3.3",
    "@tailwindcss/typography" => "0.5.20"
  }
  @runtime_package_set PackageSet.bundled(:volt, :tailwind, @tailwind_runtime_deps)

  def runtime_packages, do: @tailwind_runtime_deps
  def runtime_package_set, do: @runtime_package_set

  def handlers(runtime_node_modules) do
    %{
      "tailwind.load_stylesheet" => fn [id, base] ->
        load_stylesheet(id, base, runtime_node_modules)
      end,
      "tailwind.load_module" => fn [id, base, kind] ->
        load_module(id, base, kind, runtime_node_modules)
      end
    }
  end

  defp load_stylesheet(id, base, runtime_node_modules) do
    path = Resolver.resolve_stylesheet_path!(id, base, runtime_node_modules)

    %{
      base: Path.dirname(path),
      content: File.read!(path)
    }
  end

  defp load_module(id, base, kind, runtime_node_modules) do
    path = Resolver.resolve_module_path!(id, base, kind, runtime_node_modules)

    {code, format} =
      if Path.extname(path) == ".json" do
        {File.read!(path), "json"}
      else
        {bundle_module_source!(path, runtime_node_modules), "cjs"}
      end

    %{
      path: path,
      base: Path.dirname(path),
      code: code,
      format: format
    }
  end

  defp bundle_module_source!(entry_path, runtime_node_modules) do
    with {:ok, files} <- collect_bundle_files(entry_path, runtime_node_modules) do
      case OXC.bundle(files, entry: entry_path, format: :cjs) do
        {:ok, code} when is_binary(code) ->
          code

        {:ok, %{code: code}} when is_binary(code) ->
          code

        {:error, errors} ->
          raise "Could not bundle Tailwind module #{inspect(entry_path)}: #{inspect(errors)}"
      end
    else
      {:error, reason} ->
        raise "Could not collect Tailwind module graph for #{inspect(entry_path)}: #{inspect(reason)}"
    end
  end

  defp collect_bundle_files(entry_path, runtime_node_modules) do
    case do_collect_bundle_files(entry_path, runtime_node_modules, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect_bundle_files(abs_path, runtime_node_modules, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      with {:ok, source} <- File.read(abs_path),
           {:ok, rewritten_source, resolved_paths} <-
             rewrite_bundle_source(source, abs_path, runtime_node_modules) do
        seen = MapSet.put(seen, abs_path)
        files = [{abs_path, rewritten_source} | files]
        collect_bundle_dependencies(resolved_paths, runtime_node_modules, files, seen)
      else
        {:error, reason} when is_atom(reason) ->
          {:error, {:file_read_error, abs_path, reason}}

        {:error, _} = error ->
          error
      end
    end
  end

  defp collect_bundle_dependencies([], _runtime_node_modules, files, seen), do: {:ok, files, seen}

  defp collect_bundle_dependencies([path | rest], runtime_node_modules, files, seen) do
    case do_collect_bundle_files(path, runtime_node_modules, files, seen) do
      {:ok, files, seen} -> collect_bundle_dependencies(rest, runtime_node_modules, files, seen)
      {:error, _} = error -> error
    end
  end

  defp rewrite_bundle_source(source, abs_path, runtime_node_modules) do
    Specifiers.rewrite(source, abs_path, runtime_node_modules, &bundle_specifier/3)
  end

  defp bundle_specifier(specifier, abs_path, runtime_node_modules) do
    if Resolver.node_builtin_specifier?(specifier) do
      :skip
    else
      resolved_path =
        Resolver.resolve_module_path!(
          specifier,
          Path.dirname(abs_path),
          "require",
          runtime_node_modules
        )

      cond do
        Path.extname(resolved_path) == ".json" ->
          :skip

        Resolver.relative_specifier?(specifier) ->
          {:ok, nil, resolved_path}

        true ->
          relative = compute_relative_path(abs_path, resolved_path)
          {:ok, relative, resolved_path}
      end
    end
  rescue
    error in RuntimeError ->
      {:error, Exception.message(error)}
  end

  defp compute_relative_path(importer_path, resolved_path) do
    {importer_rest, resolved_rest} =
      drop_shared_segments(
        Path.dirname(importer_path) |> Path.split(),
        Path.split(resolved_path)
      )

    path =
      (List.duplicate("..", length(importer_rest)) ++ resolved_rest)
      |> Enum.join("/")

    if String.starts_with?(path, ["./", "../"]), do: path, else: "./" <> path
  end

  defp drop_shared_segments([s | rest_a], [s | rest_b]), do: drop_shared_segments(rest_a, rest_b)
  defp drop_shared_segments(a, b), do: {a, b}
end
