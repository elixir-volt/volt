defmodule Volt.Watcher.Ignore do
  @moduledoc false

  @default_patterns [
    "**/.git/**",
    "**/node_modules/**",
    "**/test-results/**",
    "**/_build/**",
    "**/deps/**"
  ]

  @spec compile([String.t()], [String.t()]) :: [GlobEx.t()]
  def compile(patterns, roots) do
    (@default_patterns ++ patterns)
    |> Enum.uniq()
    |> Enum.flat_map(&compile_pattern(&1, roots))
  end

  defp compile_pattern(pattern, roots) do
    case Path.type(pattern) do
      :relative -> Enum.map(roots, &compile_relative(pattern, &1))
      _absolute -> [GlobEx.compile!(pattern, match_dot: true)]
    end
  end

  defp compile_relative(pattern, root) do
    root
    |> Path.join(pattern)
    |> GlobEx.compile!(match_dot: true)
  end
end
