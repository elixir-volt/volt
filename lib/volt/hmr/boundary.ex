defmodule Volt.HMR.Boundary do
  @moduledoc """
  Detect HMR boundaries by scanning for `import.meta.hot.accept()` calls.

  When a file changes, walks the dependency graph upward from the changed
  file to find the nearest module that self-accepts HMR updates. If found,
  only that module is re-imported by the client. Otherwise, a full reload
  is triggered.
  """

  @doc """
  Check if a module's source code contains `import.meta.hot.accept()`.
  """
  @spec self_accepting?(String.t()) :: boolean()
  def self_accepting?(source) do
    String.contains?(source, "import.meta.hot.accept(")
  end

  @doc """
  Find the HMR boundary for a changed file.

  Walks upward through the dependency graph from `changed_path`. Returns
  `{:ok, boundary_path}` if a self-accepting module is found, or
  `:full_reload` if the change bubbles up to the root without finding
  a boundary.

  The `read_source` function is called with an absolute path and should
  return the module's source code for boundary detection.
  """
  @spec find_boundary(String.t(), (String.t() -> String.t() | nil)) ::
          {:ok, String.t()} | :full_reload
  def find_boundary(changed_path, read_source) do
    source = read_source.(changed_path)

    if source && self_accepting?(source) do
      {:ok, changed_path}
    else
      walk_up(changed_path, read_source, MapSet.new([changed_path]))
    end
  end

  defp walk_up(path, read_source, visited) do
    case find_importers(path) do
      [] -> :full_reload
      parents -> find_boundary_in_parents(parents, read_source, visited)
    end
  end

  defp find_boundary_in_parents(parents, read_source, visited) do
    Enum.find_value(parents, :full_reload, fn parent ->
      if MapSet.member?(visited, parent) do
        nil
      else
        visit_parent(parent, read_source, MapSet.put(visited, parent))
      end
    end)
  end

  defp visit_parent(parent, read_source, visited) do
    source = read_source.(parent)

    cond do
      source != nil and self_accepting?(source) ->
        {:ok, parent}

      true ->
        case walk_up(parent, read_source, visited) do
          {:ok, _} = found -> found
          :full_reload -> nil
        end
    end
  end

  defp find_importers(path) do
    basename = Path.basename(path)
    rootname = Path.rootname(basename)

    Volt.DepGraph.dependents_matching(fn specifier ->
      spec_base = specifier |> String.split("/") |> List.last()

      spec_base == basename or
        spec_base == rootname or
        Path.rootname(spec_base) == rootname
    end)
  end
end
