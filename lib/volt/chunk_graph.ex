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
  """

  defstruct chunks: %{}, module_to_chunk: %{}

  @type chunk :: %{
          id: String.t(),
          type: :entry | :async | :common,
          modules: [String.t()],
          imports: [String.t()]
        }

  @doc """
  Build chunks from a module graph.

  `modules` is a list of `{abs_path, label, source}` tuples in dependency order.
  `dep_map` maps `abs_path => %{static: [abs_path], dynamic: [abs_path]}`.
  `entry_path` is the absolute path of the entry file.
  """
  @spec build(String.t(), [{String.t(), String.t(), String.t()}], %{String.t() => map()}) ::
          %__MODULE__{}
  def build(entry_path, modules, dep_map) do
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

    module_to_chunk =
      Enum.reduce(Map.values(chunks), module_to_chunk, fn chunk, acc ->
        Enum.reduce(chunk.modules, acc, fn mod, a -> Map.put_new(a, mod, chunk.id) end)
      end)

    %__MODULE__{chunks: chunks, module_to_chunk: module_to_chunk}
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
