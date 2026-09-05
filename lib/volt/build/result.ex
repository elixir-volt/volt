defmodule Volt.Build.Result do
  @moduledoc "Complete frontend build result with script and stylesheet outputs."

  @enforce_keys [:assets, :styles, :manifest]
  defstruct assets: nil, styles: [], manifest: %{}

  @type t :: %__MODULE__{
          assets: Volt.Builder.Result.t(),
          styles: [Volt.Builder.OutputFile.t()],
          manifest: %{String.t() => Volt.Builder.ManifestEntry.t()}
        }
end
