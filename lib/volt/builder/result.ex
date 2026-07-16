defmodule Volt.Builder.Result do
  @moduledoc "Production build result returned from `Volt.Builder`."

  defstruct js: [], css: nil, manifest: %{}, chunks: []

  @type t :: %__MODULE__{
          js: Volt.Builder.OutputFile.t() | [Volt.Builder.OutputFile.t()],
          css: Volt.Builder.OutputFile.t() | nil,
          manifest: %{String.t() => Volt.Builder.ManifestEntry.t()},
          chunks: [Volt.Builder.OutputFile.t()]
        }

  @behaviour Access

  @impl Access
  def fetch(result, key), do: Map.fetch(result, key)

  @impl Access
  def get_and_update(result, key, fun), do: Map.get_and_update(result, key, fun)

  @impl Access
  def pop(result, key), do: Map.pop(result, key)
end
