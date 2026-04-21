defmodule Volt.JS.Helpers do
  @moduledoc false

  @format_extensions ~w(.js .ts .jsx .tsx)

  def discover_files(opts \\ []) do
    config = Volt.Config.build()
    root = config.root
    sources = config.sources
    ignore = config.ignore
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
    discover_files(only: @format_extensions)
  end
end
