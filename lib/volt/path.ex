defmodule Volt.Path do
  @moduledoc "Filesystem path helpers shared across Volt runtime modules."

  def inside?(path, root) do
    path = Path.expand(path)
    root = Path.expand(root)
    path == root or String.starts_with?(path, root <> "/")
  end

  @doc "Build a relative JavaScript import specifier from one file to another."
  @spec relative_import(String.t(), String.t()) :: String.t()
  def relative_import(from, to) do
    from_parts = from |> Path.dirname() |> Path.expand() |> Path.split()
    to_parts = to |> Path.expand() |> Path.split()
    {from_rest, to_rest} = trim_common_parts(from_parts, to_parts)

    relative =
      List.duplicate("..", length(from_rest))
      |> Kernel.++(to_rest)
      |> Enum.join("/")

    relative
    |> ensure_relative_import()
    |> String.replace("\\", "/")
  end

  defp trim_common_parts([part | left], [part | right]), do: trim_common_parts(left, right)
  defp trim_common_parts(left, right), do: {left, right}

  defp ensure_relative_import("." <> _ = path), do: path
  defp ensure_relative_import(path), do: "./" <> path
end
