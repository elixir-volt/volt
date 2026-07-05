defmodule Volt.Test.Discovery do
  @moduledoc """
  Discovers JavaScript and TypeScript test files for the Volt test runner.

  Discovery is intentionally aligned with `Volt.JS.Helpers`: configured include
  globs are expanded relative to `Volt.Test.Config.root`, exclude globs are
  expanded from the same root, non-files are ignored, and results are sorted for
  deterministic ExUnit generation.
  """

  alias Volt.Test.Config

  @spec files(Config.t() | keyword()) :: [String.t()]
  def files(config_or_opts \\ [])

  def files(%Config{} = config), do: discover(config)
  def files(opts) when is_list(opts), do: opts |> Config.read() |> discover()

  @spec files(atom() | nil, keyword()) :: [String.t()]
  def files(profile, overrides) do
    profile
    |> Config.read(overrides)
    |> discover()
  end

  defp discover(%Config{} = config) do
    root = config.root

    matched = expand_patterns(root, config.include)
    ignored = root |> expand_patterns(config.exclude) |> MapSet.new()

    matched
    |> Enum.reject(&MapSet.member?(ignored, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
  end

  defp expand_patterns(root, patterns) do
    Enum.flat_map(patterns, fn pattern ->
      root
      |> Path.join(pattern)
      |> Path.wildcard()
    end)
  end
end
