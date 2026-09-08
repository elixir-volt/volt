defmodule Volt.HMR.ModuleGraph do
  @moduledoc "Session-scoped module graph indexed by URL, resolved identity, and source file."

  alias Volt.ETS

  @table :volt_hmr_module_graph

  defmodule Node do
    @moduledoc "A served browser module."
    defstruct url: nil,
              id: nil,
              file: nil,
              type: :js,
              imports: MapSet.new(),
              importers: MapSet.new(),
              self_accepting: false,
              last_invalidated_at: nil
  end

  def create_table, do: ETS.create_named_set(@table)

  def update_module(url, id, file, imports, opts \\ []) do
    session = Keyword.get(opts, :session, :default)
    old = get_by_id(id, session)
    unlink_imports(old, session)
    if old && old.url != url, do: ETS.delete(@table, {session, {:url, old.url}})
    if old && old.file != file, do: unlink_file(old, session)

    importers =
      for node <- nodes(session),
          MapSet.member?(node.imports, id),
          into: MapSet.new(),
          do: node.id

    node = %Node{
      url: url,
      id: id,
      file: file,
      imports: MapSet.new(imports),
      importers: importers,
      type: Keyword.get(opts, :type, module_type(url)),
      self_accepting: Keyword.get(opts, :self_accepting, false)
    }

    put_node(node, session)

    Enum.each(node.imports, fn imported_id ->
      if imported = get_by_id(imported_id, session) do
        put_node(%{imported | importers: MapSet.put(imported.importers, id)}, session)
      end
    end)

    :ok
  end

  def get_by_url(url, session \\ :default) do
    case lookup({:url, url}, session) do
      nil -> nil
      id -> get_by_id(id, session)
    end
  end

  def get_by_id(id, session \\ :default), do: lookup({:id, id}, session)

  def get_by_file(file, session \\ :default) do
    (lookup({:file, file}, session) || MapSet.new())
    |> Enum.flat_map(&List.wrap(get_by_id(&1, session)))
  end

  def invalidate_file(file, timestamp \\ System.system_time(:millisecond), session \\ :default) do
    nodes = get_by_file(file, session)
    Enum.each(nodes, &put_node(%{&1 | last_invalidated_at: timestamp}, session))
    nodes
  end

  def remove_file(file, session \\ :default) do
    Enum.each(get_by_file(file, session), fn node ->
      unlink_imports(node, session)

      Enum.each(node.importers, fn id ->
        if importer = get_by_id(id, session) do
          put_node(%{importer | imports: MapSet.delete(importer.imports, node.id)}, session)
        end
      end)

      ETS.delete(@table, {session, {:url, node.url}})
      ETS.delete(@table, {session, {:id, node.id}})
    end)

    ETS.delete(@table, {session, {:file, file}})
  end

  def clear, do: ETS.clear(@table)
  def clear_session(session), do: ETS.clear_session(@table, session)

  defp nodes(session) do
    :ets.foldl(
      fn
        {{^session, {:id, _}}, node}, acc -> [node | acc]
        _, acc -> acc
      end,
      [],
      @table
    )
  end

  defp put_node(node, session) do
    ids = lookup({:file, node.file}, session) || MapSet.new()
    ETS.put(@table, {{session, {:url, node.url}}, node.id})
    ETS.put(@table, {{session, {:id, node.id}}, node})
    ETS.put(@table, {{session, {:file, node.file}}, MapSet.put(ids, node.id)})
  end

  defp unlink_file(node, session) do
    ids = lookup({:file, node.file}, session) || MapSet.new()
    ETS.put(@table, {{session, {:file, node.file}}, MapSet.delete(ids, node.id)})
  end

  defp unlink_imports(nil, _session), do: :ok

  defp unlink_imports(node, session) do
    Enum.each(node.imports, fn id ->
      if imported = get_by_id(id, session) do
        put_node(%{imported | importers: MapSet.delete(imported.importers, node.id)}, session)
      end
    end)
  end

  defp lookup(key, session) do
    case :ets.lookup(@table, {session, key}) do
      [{_, value}] -> value
      [] -> nil
    end
  end

  defp module_type(url) do
    cond do
      String.contains?(url, ".css") -> :css
      Volt.Assets.asset?(url) -> :asset
      true -> :js
    end
  end
end
