defmodule Volt.JS.Runtime.Bundler do
  @moduledoc false

  alias Volt.JS.PackageResolver

  @resolve_opts [extensions: Volt.JS.Extensions.node_resolvable()]

  @spec bundle_file(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def bundle_file(entry_path, opts \\ []) do
    entry_path = Path.expand(entry_path)

    node_modules =
      Keyword.get(opts, :node_modules) ||
        NPM.Resolution.PackageResolver.find_node_modules(Path.dirname(entry_path))

    project_root = project_root(entry_path, node_modules)
    entry_label = Path.relative_to(entry_path, project_root, separator: "/")

    bundle_opts =
      opts
      |> Keyword.drop([:node_modules])
      |> Keyword.put_new(:entry, entry_label)

    case collect_modules(entry_path, project_root) do
      {:ok, files} -> OXC.bundle(files, bundle_opts)
      {:error, _} = error -> error
    end
  end

  defp collect_modules(entry_path, project_root) do
    case do_collect(entry_path, project_root, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect(abs_path, project_root, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      with {:ok, source} <- File.read(abs_path),
           {:ok, rewritten, resolved_paths} <- rewrite_and_resolve(source, abs_path, project_root) do
        label = Path.relative_to(abs_path, project_root, separator: "/")
        seen = MapSet.put(seen, abs_path)
        files = [{label, rewritten} | files]
        collect_deps(resolved_paths, project_root, files, seen)
      else
        {:error, reason} when is_atom(reason) -> {:error, {:file_read_error, abs_path, reason}}
        {:error, _} = error -> error
      end
    end
  end

  defp collect_deps([], _project_root, files, seen), do: {:ok, files, seen}

  defp collect_deps([path | rest], project_root, files, seen) do
    case do_collect(path, project_root, files, seen) do
      {:ok, files, seen} -> collect_deps(rest, project_root, files, seen)
      {:error, _} = error -> error
    end
  end

  defp rewrite_and_resolve(source, importer, project_root) do
    case OXC.parse(source, Path.basename(importer)) do
      {:ok, ast} ->
        {patches, resolved_paths} = collect_specifier_patches(ast, importer, project_root)
        {:ok, OXC.patch_string(source, patches), resolved_paths}

      {:error, errors} ->
        {:error, {:parse_error, importer, errors}}
    end
  catch
    {:error, _} = error -> error
  end

  defp collect_specifier_patches(ast, importer, project_root) do
    {_ast, {patches, paths}} =
      OXC.postwalk(ast, {[], []}, fn
        %{type: type, source: %{value: specifier, start: s, end: e}}, acc
        when type in [:import_declaration, :export_all_declaration, :export_named_declaration] ->
          {nil, accumulate_patch(specifier, s, e, importer, project_root, acc)}

        %{
          type: :import_expression,
          source: %{type: :literal, value: specifier, start: s, end: e}
        } = node,
        acc
        when is_binary(specifier) ->
          {node, accumulate_patch(specifier, s, e, importer, project_root, acc)}

        %{
          type: :call_expression,
          callee: %{type: :identifier, name: "require"},
          arguments: [%{value: specifier, start: s, end: e}]
        } = node,
        acc
        when is_binary(specifier) ->
          {node, accumulate_patch(specifier, s, e, importer, project_root, acc)}

        node, acc ->
          {node, acc}
      end)

    {Enum.reverse(patches), Enum.reverse(paths)}
  end

  defp accumulate_patch(specifier, start_pos, end_pos, importer, project_root, {patches, paths}) do
    from_dir = Path.dirname(importer)

    case PackageResolver.resolve(specifier, from_dir, @resolve_opts) do
      {:builtin, _} ->
        {patches, paths}

      {:ok, resolved_path} ->
        replacement = PackageResolver.relative_import_path(importer, resolved_path, project_root)
        patch = %{start: start_pos, end: end_pos, change: inspect(replacement)}
        {[patch | patches], [resolved_path | paths]}

      :error ->
        throw({:error, {:module_not_found, specifier, "could not resolve"}})
    end
  end

  defp project_root(entry_path, nil), do: Path.dirname(entry_path)

  defp project_root(entry_path, node_modules) do
    [entry_path, node_modules]
    |> Enum.map(&Path.split/1)
    |> shared_segments()
    |> Path.join()
  end

  defp shared_segments([first | rest]) do
    first
    |> Enum.with_index()
    |> Enum.take_while(fn {segment, index} ->
      Enum.all?(rest, &(Enum.at(&1, index) == segment))
    end)
    |> Enum.map(&elem(&1, 0))
  end
end
