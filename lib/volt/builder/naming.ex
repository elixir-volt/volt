defmodule Volt.Builder.Naming do
  @moduledoc false

  @windows_reserved ~w(CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9)

  @spec entry_name(String.t(), String.t() | nil) :: String.t()
  def entry_name(path, override \\ nil)
  def entry_name(_path, override) when is_binary(override), do: file_path(override)
  def entry_name(path, nil), do: path |> Path.basename() |> Path.rootname() |> file_path()

  @spec module_label(String.t(), String.t()) :: String.t()
  def module_label(resolved_path, root) do
    {path, query} = Volt.URL.split_query(resolved_path)
    [relative_path | rest] = path |> String.split("/node_modules/") |> Enum.reverse()

    label =
      if rest != [] do
        relative_path
      else
        relative = Path.relative_to(path, root)

        if Path.type(relative) == :absolute do
          "_external/" <>
            Path.basename(Path.dirname(path)) <> "/" <> Path.basename(path)
        else
          relative
        end
      end
      |> with_query_suffix(query)

    label
    |> ensure_javascript_extension(query)
    |> file_path()
  end

  @spec unique(String.t(), String.t(), MapSet.t(String.t())) :: String.t()
  def unique(label, identity, used_labels) do
    if MapSet.member?(used_labels, label) do
      digest =
        :crypto.hash(:sha256, identity) |> Base.encode16(case: :lower) |> binary_part(0, 10)

      unique_candidate(label, digest, used_labels, 0)
    else
      label
    end
  end

  @spec file_path(String.t()) :: String.t()
  def file_path(path) do
    path
    |> String.replace("\\", "/")
    |> String.split("/", trim: false)
    |> Enum.map_join("/", &file_segment/1)
  end

  defp unique_candidate(label, digest, used_labels, attempt) do
    suffix = if attempt == 0, do: digest, else: "#{digest}-#{attempt + 1}"
    candidate = append_suffix(label, suffix)

    if MapSet.member?(used_labels, candidate) do
      unique_candidate(label, digest, used_labels, attempt + 1)
    else
      candidate
    end
  end

  defp append_suffix(path, suffix) do
    extension = Path.extname(path)
    Path.rootname(path) <> "-" <> suffix <> extension
  end

  defp with_query_suffix(label, ""), do: label

  defp with_query_suffix(label, query) do
    suffix =
      query
      |> URI.decode_query()
      |> Map.keys()
      |> Enum.sort()
      |> Enum.join("-")

    label <> "." <> suffix
  end

  defp ensure_javascript_extension(label, query) do
    cond do
      Path.extname(label) == ".json" -> Path.rootname(label) <> ".json.js"
      Path.extname(label) in Volt.JS.Extensions.css() -> label <> ".js"
      query != "" -> label <> ".js"
      true -> label
    end
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
