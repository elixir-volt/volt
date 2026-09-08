defmodule Volt.HMR.Boundary do
  @moduledoc """
  Detects HMR boundaries from the dev module graph and source ASTs.

  When a file changes, Volt first checks `Volt.HMR.ModuleGraph` for served
  importers and self-accepting modules. If the file has not entered the dev
  module graph yet, boundary lookup falls back to `Volt.HMR.ImportGraph` raw
  specifiers. If no self-accepting boundary is found, the client performs a full
  reload.
  """

  @doc """
  Check if a module's source code contains `import.meta.hot.accept()`.
  """
  @spec self_accepting?(String.t()) :: boolean()
  def self_accepting?(source) do
    case OXC.parse(source, "hmr-boundary.js") do
      {:ok, ast} -> ast_self_accepting?(ast)
      {:error, _} -> false
    end
  end

  @doc """
  Find the HMR boundary for a changed file.

  Walks upward through the module graph from `changed_path`. Returns
  `{:ok, boundary_path}` if a self-accepting module is found, or
  `:full_reload` if the change bubbles up to the root without finding
  a boundary.

  The `read_source` function is called with an absolute path and should
  return the module's source code for boundary detection.
  """
  @spec find_boundary(String.t(), (String.t() -> String.t() | nil)) ::
          {:ok, String.t()} | :full_reload
  def find_boundary(changed_path, read_source, session \\ :default) do
    source = read_source.(changed_path)

    cond do
      source && self_accepting?(source) ->
        {:ok, changed_path}

      graph_boundary = find_graph_boundary(changed_path, read_source, session) ->
        graph_boundary

      true ->
        walk_up(changed_path, changed_path, read_source, MapSet.new([changed_path]), session)
    end
  end

  defp ast_self_accepting?(ast) do
    {_ast, found?} =
      OXC.postwalk(ast, false, fn
        node, false -> {node, accept_call?(node)}
        node, true -> {node, true}
      end)

    found?
  end

  defp accept_call?(node) when is_map(node) do
    result =
      Volt.JS.AST.call_member_arguments(node, {:meta_property, "import", "meta", "hot"}, "accept")

    case result do
      {:ok, []} ->
        true

      {:ok, [%{type: type} | _]}
      when type in [:arrow_function_expression, :function_expression] ->
        true

      _ ->
        false
    end
  end

  defp accept_call?(_node), do: false

  defp dependency_accepting?(source, importer_path, changed_path) do
    source
    |> dependency_accept_specifiers()
    |> Enum.any?(&specifier_matches_changed?(&1, importer_path, changed_path))
  end

  defp dependency_accept_specifiers(source) do
    case OXC.parse(source, "hmr-boundary.js") do
      {:ok, ast} -> ast_dependency_accept_specifiers(ast)
      {:error, _} -> []
    end
  end

  defp ast_dependency_accept_specifiers(ast) do
    {_ast, specifiers} =
      OXC.postwalk(ast, [], fn
        node, specifiers -> {node, specifiers ++ dependency_accept_specifiers_from_node(node)}
      end)

    specifiers
  end

  defp dependency_accept_specifiers_from_node(node) when is_map(node) do
    case Volt.JS.AST.call_member_arguments(
           node,
           {:meta_property, "import", "meta", "hot"},
           "accept"
         ) do
      {:ok, [first | _]} -> accept_dependency_specifiers(first)
      _ -> []
    end
  end

  defp dependency_accept_specifiers_from_node(_node), do: []

  defp accept_dependency_specifiers(%{type: :literal, value: specifier})
       when is_binary(specifier),
       do: [specifier]

  defp accept_dependency_specifiers(%{type: :array_expression, elements: elements}) do
    Enum.flat_map(elements, &accept_dependency_specifiers/1)
  end

  defp accept_dependency_specifiers(_node), do: []

  defp specifier_matches_changed?(specifier, importer_path, changed_path) do
    resolved = Path.expand(Path.join(Path.dirname(importer_path), specifier))
    resolved == changed_path or Path.rootname(resolved) == Path.rootname(changed_path)
  end

  defp find_graph_boundary(changed_path, read_source, session) do
    changed_path
    |> Volt.HMR.ModuleGraph.get_by_file(session)
    |> case do
      [] ->
        nil

      nodes ->
        find_graph_boundary_in_nodes(
          nodes,
          changed_path,
          read_source,
          MapSet.new(Enum.map(nodes, & &1.id)),
          session
        )
    end
  end

  defp find_graph_boundary_in_nodes(nodes, changed_path, read_source, visited, session) do
    Enum.find_value(nodes, :full_reload, fn node ->
      cond do
        graph_accepts_update?(node, changed_path, read_source) ->
          {:ok, node.file}

        MapSet.size(node.importers) == 0 ->
          nil

        true ->
          node.importers
          |> Enum.flat_map(&List.wrap(Volt.HMR.ModuleGraph.get_by_id(&1, session)))
          |> Enum.reject(&MapSet.member?(visited, &1.id))
          |> find_graph_boundary_in_nodes(
            changed_path,
            read_source,
            MapSet.union(visited, node.importers),
            session
          )
          |> case do
            :full_reload -> nil
            found -> found
          end
      end
    end)
  end

  defp graph_accepts_update?(node, changed_path, read_source) do
    case read_source.(node.file) do
      source when is_binary(source) ->
        self_accepting?(source) or dependency_accepting?(source, node.file, changed_path)

      _ ->
        node.self_accepting
    end
  end

  defp walk_up(path, changed_path, read_source, visited, session) do
    case find_importers(path, session) do
      [] -> :full_reload
      parents -> find_boundary_in_parents(parents, changed_path, read_source, visited, session)
    end
  end

  defp find_boundary_in_parents(parents, changed_path, read_source, visited, session) do
    Enum.find_value(parents, :full_reload, fn parent ->
      if MapSet.member?(visited, parent) do
        nil
      else
        visit_parent(parent, changed_path, read_source, MapSet.put(visited, parent), session)
      end
    end)
  end

  defp visit_parent(parent, changed_path, read_source, visited, session) do
    source = read_source.(parent)

    if source != nil and
         (self_accepting?(source) or dependency_accepting?(source, parent, changed_path)) do
      {:ok, parent}
    else
      case walk_up(parent, changed_path, read_source, visited, session) do
        {:ok, _} = found -> found
        :full_reload -> nil
      end
    end
  end

  defp find_importers(path, session) do
    basename = Path.basename(path)
    rootname = Path.rootname(basename)

    Volt.HMR.ImportGraph.dependents_matching(
      fn specifier ->
        spec_base = specifier |> String.split("/") |> List.last()

        spec_base == basename or
          spec_base == rootname or
          Path.rootname(spec_base) == rootname
      end,
      session
    )
  end
end
