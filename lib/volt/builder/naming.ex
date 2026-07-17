defmodule Volt.Builder.Naming do
  @moduledoc false

  @windows_reserved ~w(CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9)

  @spec file_path(String.t()) :: String.t()
  def file_path(path) do
    path
    |> String.replace("\\", "/")
    |> String.split("/", trim: false)
    |> Enum.map_join("/", &file_segment/1)
  end

  defp file_segment(segment) do
    segment =
      segment
      |> String.replace(~r/[<>:"|?*\x00-\x1F]/u, "_")
      |> String.replace(~r/[ .]+$/u, "")

    cond do
      segment == "" -> "_"
      reserved?(segment) -> "_" <> segment
      true -> segment
    end
  end

  defp reserved?(segment) do
    segment
    |> String.split(".", parts: 2)
    |> hd()
    |> String.upcase()
    |> then(&(&1 in @windows_reserved))
  end
end
