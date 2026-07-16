defmodule Volt.JS.Helpers do
  @moduledoc "Shared JavaScript file discovery helpers for Mix tasks."

  def discover_files(opts \\ []) do
    config = Volt.Config.build()
    tool_config = discovery_config(Keyword.get(opts, :tool))
    root = Keyword.get(tool_config, :root, config.root)
    sources = Keyword.get(tool_config, :sources, config.sources)
    ignore = Keyword.get(tool_config, :ignore, config.ignore)
    only = Keyword.get(opts, :only)

    matched =
      Enum.flat_map(sources, fn pattern ->
        Path.wildcard(Path.join(root, pattern))
      end)

    ignored =
      Enum.flat_map(ignore, fn pattern ->
        Path.wildcard(Path.join(root, pattern))
      end)

    ignored_set = MapSet.new(ignored)

    matched
    |> Enum.reject(&MapSet.member?(ignored_set, &1))
    |> Enum.filter(&File.regular?/1)
    |> then(fn files ->
      case only do
        nil -> files
        exts -> Enum.filter(files, &(Path.extname(&1) in exts))
      end
    end)
    |> Enum.sort()
  end

  def discover_format_files do
    discover_files(tool: :format, only: Volt.JS.Extensions.formattable())
  end

  defp discovery_config(nil), do: []
  defp discovery_config(tool), do: Application.get_env(:volt, tool, [])
end
