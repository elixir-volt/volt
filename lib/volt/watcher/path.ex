defmodule Volt.Watcher.Path do
  @moduledoc false

  @spec normalize_from_roots(String.t(), [String.t()]) :: String.t()
  def normalize_from_roots(path, roots) do
    path = Path.expand(path)

    Enum.find_value(roots, path, fn root ->
      root = Path.expand(root)

      if Volt.Path.inside?(path, root) do
        path
      else
        normalize_from_physical_root(path, root)
      end
    end)
  end

  defp normalize_from_physical_root(path, root) do
    with {:ok, root_stat} <- File.stat(root),
         {:ok, relative} <- relative_to_physical_root(path, root_stat, []) do
      Path.expand(relative, root)
    else
      _not_found -> nil
    end
  end

  defp relative_to_physical_root(path, root_stat, parts) do
    case File.stat(path) do
      {:ok, path_stat} ->
        if same_file?(path_stat, root_stat) do
          {:ok, Path.join(parts)}
        else
          continue_to_parent(path, root_stat, parts)
        end

      _error ->
        continue_to_parent(path, root_stat, parts)
    end
  end

  defp continue_to_parent(path, root_stat, parts) do
    parent = Path.dirname(path)

    if parent == path do
      :error
    else
      relative_to_physical_root(parent, root_stat, [Path.basename(path) | parts])
    end
  end

  defp same_file?(left, right) do
    left.major_device == right.major_device and left.minor_device == right.minor_device and
      left.inode == right.inode
  end
end
