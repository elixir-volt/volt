defmodule Volt.Test.Bundler do
  @moduledoc """
  Bundles a Volt JS/TS test file and its relative module graph.

  This is intentionally narrower than the production builder: it supports local
  relative JavaScript/TypeScript/JSON imports so tests can exercise nearby
  modules, while Volt test virtual imports are stripped before bundling.
  """

  alias Volt.JS.Extensions
  alias Volt.Test.Bundle

  @spec bundle_file(Path.t(), keyword()) :: {:ok, Bundle.t()} | {:error, term()}
  def bundle_file(entry_path, opts \\ []) do
    entry_path = Path.expand(entry_path)

    with {:ok, modules} <- collect(entry_path),
         root = common_root(Map.keys(modules)),
         files = labeled_files(modules, root),
         entry = label(entry_path, root),
         {:ok, output} <- OXC.bundle(files, bundle_opts(entry, opts)) do
      {:ok, bundle(output, entry_path, Map.keys(modules))}
    end
  end

  defp collect(entry_path) do
    do_collect(entry_path, %{})
  end

  defp do_collect(path, modules) do
    if Map.has_key?(modules, path) do
      {:ok, modules}
    else
      with {:ok, source} <- read_and_prepare(path),
           {:ok, imports} <- imports(source, path) do
        modules = Map.put(modules, path, source)
        collect_imports(imports, path, modules)
      else
        {:error, reason} when is_atom(reason) -> {:error, {:file_read_error, path, reason}}
        {:error, _} = error -> error
      end
    end
  end

  defp read_and_prepare(path) do
    with {:ok, source} <- File.read(path) do
      Volt.Test.Imports.strip(source, Path.basename(path))
    end
  end

  defp imports(source, path) do
    with {:ok, result} <- Volt.JS.ImportExtractor.extract_typed(source, Path.basename(path)) do
      imports =
        result.imports
        |> Enum.map(&elem(&1, 1))
        |> Enum.filter(&relative_specifier?/1)

      {:ok, imports}
    end
  end

  defp collect_imports([], _importer, modules), do: {:ok, modules}

  defp collect_imports([specifier | rest], importer, modules) do
    with {:ok, resolved} <- resolve(specifier, importer),
         {:ok, modules} <- do_collect(resolved, modules) do
      collect_imports(rest, importer, modules)
    end
  end

  defp resolve(specifier, importer) do
    base = Path.expand(specifier, Path.dirname(importer))
    candidates = candidate_paths(base)

    case Enum.find(candidates, &File.regular?/1) do
      nil -> {:error, {:module_not_found, specifier, importer}}
      path -> {:ok, path}
    end
  end

  defp candidate_paths(base) do
    exact_and_exts = Enum.map(Extensions.node_resolvable_with_exact(), &(base <> &1))
    index_files = Enum.map(Extensions.node_resolvable(), &Path.join(base, "index" <> &1))
    exact_and_exts ++ index_files
  end

  defp relative_specifier?("./" <> _), do: true
  defp relative_specifier?("../" <> _), do: true
  defp relative_specifier?(_), do: false

  defp labeled_files(modules, root) do
    Enum.map(modules, fn {path, source} -> {label(path, root), source} end)
  end

  defp label(path, root) do
    path
    |> Path.relative_to(root)
    |> Path.split()
    |> Enum.join("/")
  end

  defp common_root(paths) do
    paths
    |> Enum.map(&Path.split(Path.dirname(&1)))
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

  defp bundle(output, entry_path, files) do
    {code, sourcemap} = output_code_and_sourcemap(output)

    %Bundle{
      entry: entry_path,
      code: code,
      sourcemap: sourcemap,
      files: Enum.sort(files)
    }
  end

  defp output_code_and_sourcemap(%{code: code, sourcemap: sourcemap}), do: {code, sourcemap}
  defp output_code_and_sourcemap(code) when is_binary(code), do: {code, nil}

  defp bundle_opts(entry, opts) do
    opts
    |> Keyword.take([:define, :target, :sourcemap, :minify])
    |> Keyword.put(:entry, entry)
    |> Keyword.put_new(:format, :iife)
    |> Keyword.put_new(:sourcemap, true)
  end
end
