defmodule Volt.HMR.StyleDependencies do
  @moduledoc """
  Updates HMR stylesheet dependency state from compiled pipeline output.

  `Volt.CSS.Dependencies` owns parser-backed dependency discovery and
  `Volt.HMR.StyleGraph` owns ETS storage. This module bridges a compiled source
  file to that graph, choosing the CSS text that represents the file in dev:
  physical `.css` source, or emitted CSS from CSS modules and framework/plugin
  compilers.
  """

  @doc "Update stylesheet dependency state for a compiled source file."
  @spec update_from_compile(String.t(), String.t(), Volt.Pipeline.Result.t() | map()) :: :ok
  def update_from_compile(path, source, result) do
    case dependency_source(path, source, result) do
      nil ->
        Volt.HMR.StyleGraph.remove(path)

      css ->
        dependencies = Volt.CSS.Dependencies.resolve(css, path)
        Volt.HMR.StyleGraph.update(path, dependencies)
    end
  end

  defp dependency_source(path, source, %{css: css}) when is_binary(css) do
    if css_file?(path), do: source, else: css
  end

  defp dependency_source(path, source, _result) do
    if css_file?(path), do: source
  end

  defp css_file?(path), do: Path.extname(path) == ".css"
end
