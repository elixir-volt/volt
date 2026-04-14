defmodule Volt.Tailwind.Loader do
  @moduledoc "Handles Tailwind module loading, prebundling CJS graphs via OXC, and stylesheet resolution."

  alias Volt.Tailwind.Resolver

  @tailwind_install_spec "^4.2.2"
  @tailwind_runtime_deps %{
    "tailwindcss" => @tailwind_install_spec,
    "@tailwindcss/typography" => "*"
  }

  def ensure_runtime_root! do
    NPM.install(@tailwind_runtime_deps, __skip_project_check__: true)
    Path.join(NPM.node_modules_dir!(), "tailwindcss")
  end

  def handlers do
    %{
      "tailwind.load_stylesheet" => fn [id, base] -> load_stylesheet(id, base) end,
      "tailwind.load_module" => fn [id, base, kind] -> load_module(id, base, kind) end
    }
  end

  defp load_stylesheet(id, base) do
    path = Resolver.resolve_stylesheet_path!(id, base)

    %{
      base: Path.dirname(path),
      content: File.read!(path)
    }
  end

  defp load_module(id, base, kind) do
    path = Resolver.resolve_module_path!(id, base, kind)

    {code, format} =
      if Path.extname(path) == ".json" do
        {File.read!(path), "json"}
      else
        {bundle_module_source!(path), "cjs"}
      end

    %{
      path: path,
      base: Path.dirname(path),
      code: code,
      format: format
    }
  end

  defp bundle_module_source!(entry_path) do
    with {:ok, files} <- collect_bundle_files(entry_path) do
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

  defp collect_bundle_files(entry_path) do
    case do_collect_bundle_files(entry_path, [], MapSet.new()) do
      {:ok, files, _seen} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  defp do_collect_bundle_files(abs_path, files, seen) do
    if MapSet.member?(seen, abs_path) do
      {:ok, files, seen}
    else
      with {:ok, source} <- File.read(abs_path),
           {:ok, rewritten_source, resolved_paths} <- rewrite_bundle_source(source, abs_path) do
        seen = MapSet.put(seen, abs_path)
        files = [{abs_path, rewritten_source} | files]
        collect_bundle_dependencies(resolved_paths, files, seen)
      else
        {:error, reason} when is_atom(reason) ->
          {:error, {:file_read_error, abs_path, reason}}

        {:error, _} = error ->
          error
      end
    end
  end

  defp collect_bundle_dependencies([], files, seen), do: {:ok, files, seen}

  defp collect_bundle_dependencies([path | rest], files, seen) do
    case do_collect_bundle_files(path, files, seen) do
      {:ok, files, seen} -> collect_bundle_dependencies(rest, files, seen)
      {:error, _} = error -> error
    end
  end

  defp rewrite_bundle_source(source, abs_path) do
    case OXC.parse(source, Path.basename(abs_path)) do
      {:ok, ast} ->
        {patches, resolved_paths} = collect_specifier_patches(ast, abs_path)
        {:ok, OXC.patch_string(source, patches), resolved_paths}

      {:error, errors} ->
        {:error, {:parse_error, abs_path, errors}}
    end
  end

  defp collect_specifier_patches(ast, abs_path) do
    {_ast, {patches, paths}} =
      OXC.postwalk(ast, {[], []}, fn
        %{type: type, source: %{value: specifier, start: s, end: e}}, acc
        when type in ["ImportDeclaration", "ExportAllDeclaration", "ExportNamedDeclaration"] ->
          {nil, accumulate_patch(specifier, s, e, abs_path, acc)}

        %{
          type: "ImportExpression",
          source: %{type: "Literal", value: specifier, start: s, end: e}
        } = node,
        acc
        when is_binary(specifier) ->
          {node, accumulate_patch(specifier, s, e, abs_path, acc)}

        %{
          type: "CallExpression",
          callee: %{type: "Identifier", name: "require"},
          arguments: [%{value: specifier, start: s, end: e}]
        },
        acc
        when is_binary(specifier) ->
          {nil, accumulate_patch(specifier, s, e, abs_path, acc)}

        node, acc ->
          {node, acc}
      end)

    {Enum.reverse(patches), Enum.reverse(paths)}
  end

  defp accumulate_patch(specifier, start_pos, end_pos, abs_path, {patches, paths}) do
    case bundle_specifier(specifier, abs_path) do
      :skip ->
        {patches, paths}

      {:ok, nil, resolved_path} ->
        {patches, [resolved_path | paths]}

      {:ok, replacement, resolved_path} ->
        patch = %{start: start_pos, end: end_pos, change: inspect(replacement)}
        {[patch | patches], [resolved_path | paths]}

      {:error, _} ->
        {patches, paths}
    end
  end

  defp bundle_specifier(specifier, abs_path) do
    cond do
      Resolver.node_builtin_specifier?(specifier) ->
        :skip

      true ->
        resolved_path =
          Resolver.resolve_module_path!(specifier, Path.dirname(abs_path), "require")

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
