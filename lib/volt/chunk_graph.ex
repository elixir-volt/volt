defmodule Volt.ChunkGraph do
  @moduledoc """
  Build a chunk graph from module dependencies.

  Splits modules into chunks based on dynamic import boundaries:
  - The entry chunk contains all modules reachable via static imports
  - Each dynamic `import()` creates a new async chunk
  - Modules shared between multiple chunks are extracted into common chunks

  ## Chunk types

    * `:entry` — the main bundle, loaded synchronously
    * `:async` — loaded on demand via dynamic import
    * `:common` — shared code extracted to avoid duplication
    * `:manual` — user-defined chunk via `chunks` config

  ## Manual chunks

  Users can control chunk boundaries via config:

      config :volt,
        chunks: %{
          "vendor" => ["vue", "vue-router", "pinia"],
          "ui" => ["assets/src/components"]
        }

  Patterns match module paths: bare specifiers match package names in
  `node_modules`, while path patterns match against the full module path.
  """

  defstruct chunks: %{}, module_to_chunk: %{}

  @type chunk :: %{
          id: String.t(),
          type: :entry | :async | :common | :manual,
          modules: [String.t()],
          imports: [String.t()]
        }

  @doc """
  Build chunks from a module graph.

  `modules` is a list of `{abs_path, label, source}` tuples in dependency order.
  `dep_map` maps `abs_path => %{static: [abs_path], dynamic: [abs_path]}`.
  `entry_path` is the absolute path of the entry file.

  ## Options

    * `:manual_chunks` — map of chunk name to list of patterns,
      e.g. `%{"vendor" => ["vue", "vue-router"]}`
  """
  def build(entry_path, modules, dep_map, opts \\ []) do
    module_set = MapSet.new(modules, fn {path, _, _} -> path end)

    static_reachable = reachable_static(entry_path, dep_map, module_set)

    dynamic_entries =
      dep_map
      |> Enum.flat_map(fn {from, %{dynamic: dyn}} ->
        if MapSet.member?(static_reachable, from) do
          Enum.filter(dyn, &MapSet.member?(module_set, &1))
        else
          []
        end
      end)
      |> Enum.uniq()

    async_chunks =
      dynamic_entries
      |> Enum.reject(&MapSet.member?(static_reachable, &1))
      |> Enum.map(fn dyn_entry ->
        chunk_modules = reachable_static(dyn_entry, dep_map, module_set)
        chunk_id = dyn_entry |> Path.basename() |> Path.rootname()
        {dyn_entry, chunk_id, chunk_modules}
      end)

    entry_modules = static_reachable

    all_async_modules =
      Enum.flat_map(async_chunks, fn {_, _, mods} -> MapSet.to_list(mods) end) |> MapSet.new()

    shared =
      entry_modules
      |> MapSet.intersection(all_async_modules)
      |> MapSet.to_list()

    {entry_modules, common_chunk} =
      if shared == [] do
        {entry_modules, nil}
      else
        shared_set = MapSet.new(shared)
        trimmed = MapSet.difference(entry_modules, shared_set)
        {trimmed, shared_set}
      end

    async_chunks =
      if common_chunk do
        Enum.map(async_chunks, fn {entry, id, mods} ->
          {entry, id, MapSet.difference(mods, common_chunk)}
        end)
      else
        async_chunks
      end

    module_order = modules |> Enum.with_index() |> Map.new(fn {{path, _, _}, i} -> {path, i} end)
    order = fn set -> set |> MapSet.to_list() |> Enum.sort_by(&Map.get(module_order, &1, 0)) end

    chunks = %{
      "entry" => %{
        id: "entry",
        type: :entry,
        modules: order.(entry_modules),
        imports: if(common_chunk, do: ["common"], else: [])
      }
    }

    chunks =
      if common_chunk do
        Map.put(chunks, "common", %{
          id: "common",
          type: :common,
          modules: order.(common_chunk),
          imports: []
        })
      else
        chunks
      end

    {chunks, module_to_chunk} =
      Enum.reduce(async_chunks, {chunks, %{}}, fn {dyn_entry, id, mods}, {ch, m2c} ->
        id = unique_id(id, ch)
        deps = if common_chunk, do: ["common"], else: []

        chunk = %{
          id: id,
          type: :async,
          modules: order.(mods),
          imports: deps
        }

        m2c = Map.put(m2c, dyn_entry, id)
        {Map.put(ch, id, chunk), m2c}
      end)

    manual_chunks = Keyword.get(opts, :manual_chunks, %{})
    {chunks, module_to_chunk} = apply_manual_chunks(chunks, module_to_chunk, manual_chunks, order)

    module_to_chunk =
      Enum.reduce(Map.values(chunks), module_to_chunk, fn chunk, acc ->
        Enum.reduce(chunk.modules, acc, fn mod, a -> Map.put_new(a, mod, chunk.id) end)
      end)

    %__MODULE__{chunks: chunks, module_to_chunk: module_to_chunk}
  end

  defp apply_manual_chunks(chunks, module_to_chunk, manual_chunks, _order)
       when map_size(manual_chunks) == 0 do
    {chunks, module_to_chunk}
  end

  defp apply_manual_chunks(chunks, module_to_chunk, manual_chunks, order) do
    all_modules =
      chunks
      |> Map.values()
      |> Enum.flat_map(& &1.modules)

    assignments =
      Enum.reduce(all_modules, %{}, fn mod_path, acc ->
        case find_manual_chunk(mod_path, manual_chunks) do
          nil -> acc
          chunk_name -> Map.update(acc, chunk_name, [mod_path], &[mod_path | &1])
        end
      end)

    Enum.reduce(assignments, {chunks, module_to_chunk}, fn {chunk_name, mod_paths}, {ch, m2c} ->
      mod_set = MapSet.new(mod_paths)

      ch =
        Map.new(ch, fn {id, chunk} ->
          {id, %{chunk | modules: Enum.reject(chunk.modules, &MapSet.member?(mod_set, &1))}}
        end)

      ch = Map.reject(ch, fn {id, chunk} -> chunk.modules == [] and id != "entry" end)

      entry_imports = (ch["entry"].imports ++ [chunk_name]) |> Enum.uniq()
      ch = put_in(ch["entry"].imports, entry_imports)

      manual = %{
        id: chunk_name,
        type: :manual,
        modules: order.(MapSet.new(mod_paths)),
        imports: []
      }

      m2c =
        Enum.reduce(mod_paths, m2c, fn mod, a ->
          Map.put(a, mod, chunk_name)
        end)

      {Map.put(ch, chunk_name, manual), m2c}
    end)
  end

  defp find_manual_chunk(mod_path, manual_chunks) do
    Enum.find_value(manual_chunks, fn {chunk_name, patterns} ->
      if Enum.any?(patterns, &matches_pattern?(mod_path, &1)) do
        chunk_name
      end
    end)
  end

  defp matches_pattern?(mod_path, pattern) do
    if path_pattern?(pattern) do
      expanded = Path.expand(pattern)
      String.starts_with?(mod_path, expanded <> "/") or mod_path == expanded
    else
      String.contains?(mod_path, "/node_modules/#{pattern}/") or
        String.ends_with?(mod_path, "/node_modules/#{pattern}")
    end
  end

  defp path_pattern?(pattern) do
    String.starts_with?(pattern, "/") or
      String.starts_with?(pattern, "./") or
      String.starts_with?(pattern, "../") or
      String.contains?(pattern, "/")
  end

  defp reachable_static(start, dep_map, module_set) do
    do_reachable([start], dep_map, module_set, MapSet.new())
  end

  defp do_reachable([], _dep_map, _module_set, visited), do: visited

  defp do_reachable([path | rest], dep_map, module_set, visited) do
    if MapSet.member?(visited, path) or not MapSet.member?(module_set, path) do
      do_reachable(rest, dep_map, module_set, visited)
    else
      visited = MapSet.put(visited, path)
      static_deps = get_in(dep_map, [path, :static]) || []
      do_reachable(static_deps ++ rest, dep_map, module_set, visited)
    end
  end

  defp unique_id(id, chunks) do
    if Map.has_key?(chunks, id) do
      unique_id(id <> "_", chunks)
    else
      id
    end
  end
end
