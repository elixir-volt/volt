defmodule Volt.JS.Runtime.Bundler do
  @moduledoc "Bundles QuickBEAM runtime entry files and their dependencies."

  alias Volt.JS.Transforms.Specifiers

  @resolve_opts [
    extensions: Volt.JS.Extensions.node_resolvable(),
    conditions: Volt.JS.Resolution.browser_conditions()
  ]

  @spec bundle_file(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def bundle_file(entry_path, opts \\ []) do
    entry_path = Path.expand(entry_path)

    node_modules =
      Keyword.get(opts, :node_modules) ||
        NPM.Resolution.PackageResolver.find_node_modules(Path.dirname(entry_path))

    project_root = project_root(entry_path, node_modules)
    entry_label = posix_relative_to(entry_path, project_root)

    bundle_opts =
      opts
      |> Keyword.drop([:node_modules, :builtin_shims])
      |> Keyword.put_new(:entry, entry_label)

    case collect_modules(entry_path, project_root, opts) do
      {:ok, files} -> OXC.bundle(files, bundle_opts)
      {:error, _} = error -> error
    end
  end

  defp collect_modules(entry_path, project_root, opts) do
    builtin_shims = opts |> Keyword.get(:builtin_shims, %{}) |> Map.new()

    context = %{
      project_root: project_root,
      builtin_shims: builtin_shims,
      shim_labels: shim_labels(builtin_shims)
    }

    case do_collect(entry_path, context, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, context, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      with {:ok, source} <- File.read(abs_path),
           {:ok, rewritten, resolved_paths} <- rewrite_and_resolve(source, abs_path, context) do
        label = label_for(abs_path, context)
        seen = MapSet.put(seen, abs_path)
        files = [{label, rewritten} | files]
        collect_deps(resolved_paths, context, files, seen)
      else
        {:error, reason} when is_atom(reason) -> {:error, {:file_read_error, abs_path, reason}}
        {:error, _} = error -> error
      end
    end
  end

  defp collect_deps([], _context, files, seen), do: {:ok, files, seen}

  defp collect_deps([path | rest], context, files, seen) do
    case do_collect(path, context, files, seen) do
      {:ok, files, seen} -> collect_deps(rest, context, files, seen)
      {:error, _} = error -> error
    end
  end

  defp rewrite_and_resolve(source, importer, context) do
    Specifiers.rewrite(source, importer, context, &rewrite_specifier/3)
  end

  defp rewrite_specifier(specifier, importer, context) do
    project_root = context.project_root
    from_dir = Path.dirname(importer)

    case NPM.Resolution.PackageResolver.resolve(specifier, from_dir, @resolve_opts) do
      {:builtin, builtin} ->
        rewrite_builtin(specifier, builtin, importer, project_root, context.builtin_shims)

      {:ok, resolved_path} ->
        replacement =
          NPM.Resolution.PackageResolver.relative_import_path(
            importer,
            resolved_path,
            project_root
          )

        {:ok, replacement, resolved_path}

      :error ->
        throw({:error, {:module_not_found, specifier, "could not resolve"}})
    end
  end

  defp rewrite_builtin(specifier, builtin, importer, project_root, builtin_shims) do
    shim = Map.get(builtin_shims, builtin) || Map.get(builtin_shims, specifier)

    case shim do
      nil ->
        :skip

      shim_path ->
        shim_path = Path.expand(shim_path)

        replacement = relative_import_path(importer, shim_path, project_root)

        {:ok, replacement, shim_path}
    end
  end

  defp shim_labels(builtin_shims) do
    builtin_shims
    |> Enum.map(fn {_builtin, path} -> {Path.expand(path), shim_label_for_path(path)} end)
    |> Map.new()
  end

  defp label_for(path, context) do
    Map.get(context.shim_labels, path) || posix_relative_to(path, context.project_root)
  end

  defp relative_import_path(importer, resolved_path, project_root) do
    if Volt.Path.inside?(resolved_path, project_root) do
      NPM.Resolution.PackageResolver.relative_import_path(importer, resolved_path, project_root)
    else
      importer_label = posix_relative_to(importer, project_root)
      target_label = shim_label_for_path(resolved_path)
      Volt.Path.relative_import("/" <> importer_label, "/" <> target_label)
    end
  end

  defp shim_label_for_path(path) do
    "__volt_builtin_shims__/" <> Path.basename(path)
  end

  defp posix_relative_to(path, root) do
    path
    |> Path.relative_to(root)
    |> Path.split()
    |> Enum.join("/")
  end

  defp project_root(entry_path, nil), do: Path.dirname(entry_path)

  defp project_root(entry_path, node_modules) do
    [entry_path, node_modules]
    |> Enum.map(&Path.split/1)
    |> shared_segments()
    |> Path.join()
  end

  defp shared_segments([first | rest]) do
    rest_tuples = Enum.map(rest, &List.to_tuple/1)

    first
    |> Enum.with_index()
    |> Enum.take_while(fn {segment, index} ->
      Enum.all?(rest_tuples, fn t -> index < tuple_size(t) and elem(t, index) == segment end)
    end)
    |> Enum.map(&elem(&1, 0))
  end
end
