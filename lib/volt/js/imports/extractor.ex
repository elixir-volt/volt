defmodule Volt.JS.ImportExtractor do
  @moduledoc "Extracts static, dynamic, CJS, and worker imports from JavaScript source."

  @type import_type :: :static | :dynamic
  @type result :: Volt.JS.ImportExtractor.Result.t()

  @spec extract_typed(String.t(), String.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def extract_typed(source, filename, opts \\ []) do
    with {:ok, imports} <- OXC.select(source, filename, :import_sources),
         {:ok, require_calls} <- select_require_calls(source, filename, opts),
         {:ok, workers} <- select_workers(source, filename) do
      typed = Enum.map(imports, &{&1.type, &1.specifier}) ++ require_calls
      {:ok, %Volt.JS.ImportExtractor.Result{imports: typed, workers: workers}}
    end
  end

  defp select_require_calls(source, filename, opts) do
    if Keyword.get(opts, :include_require, false) do
      case OXC.select(source, filename, :require_calls) do
        {:ok, require_calls} -> {:ok, Enum.map(require_calls, &{:static, &1.specifier})}
        {:error, _} = error -> error
      end
    else
      {:ok, []}
    end
  end

  defp select_workers(source, filename) do
    case OXC.select(source, filename, :workers) do
      {:ok, workers} -> {:ok, Enum.map(workers, & &1.specifier)}
      {:error, _} = error -> error
    end
  end
end
