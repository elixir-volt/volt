defmodule Volt.HMR.GlobGraph do
  @moduledoc "Tracks `import.meta.glob()` ownership for HMR invalidation."

  @table :volt_hmr_glob_graph

  @doc "Create the glob graph ETS table."
  def create_table, do: Volt.ETS.create_named_set(@table)

  @doc "Store glob patterns owned by an importer."
  def update(importer, globs, session \\ :default),
    do: Volt.ETS.put(@table, {{session, importer}, globs})

  @doc "Extract and store `import.meta.glob()` patterns from source."
  def update_from_source(path, source, session \\ :default) do
    globs =
      source
      |> Volt.JS.Transforms.GlobImports.patterns(Path.basename(path))
      |> Enum.map(&expand_glob_pattern(&1, Path.dirname(path)))

    update(path, globs, session)
  end

  @doc "Find all files with an `import.meta.glob()` pattern matching `path`."
  def dependents(path, session \\ :default) do
    :ets.foldl(
      fn
        {{^session, importer}, globs}, acc ->
          if glob_match?(globs, path), do: [importer | acc], else: acc

        _, acc ->
          acc
      end,
      [],
      @table
    )
  end

  def remove(path, session \\ :default), do: Volt.ETS.delete(@table, {session, path})

  @doc "Remove glob ownership for one session."
  def clear_session(session), do: Volt.ETS.clear_session(@table, session)

  def clear, do: Volt.ETS.clear(@table)

  defp expand_glob_pattern("!" <> pattern, base_dir), do: "!" <> Path.expand(pattern, base_dir)
  defp expand_glob_pattern(pattern, base_dir), do: Path.expand(pattern, base_dir)

  defp glob_match?(globs, path) do
    {negative, positive} = Enum.split_with(globs, &String.starts_with?(&1, "!"))

    positive_match? = Enum.any?(positive, &pattern_match?(&1, path))
    negative_match? = Enum.any?(negative, fn "!" <> pattern -> pattern_match?(pattern, path) end)

    positive_match? and not negative_match?
  end

  defp pattern_match?(pattern, path) do
    pattern
    |> GlobEx.compile!()
    |> GlobEx.match?(path)
  end
end
