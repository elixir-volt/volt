defmodule Volt.Builder.CSS.Prepared do
  @moduledoc false

  @enforce_keys [:code, :assets, :artifacts]
  defstruct [:code, :assets, :artifacts]

  @type t :: %__MODULE__{
          code: String.t(),
          assets: [Volt.Builder.Asset.t()],
          artifacts: [Volt.Builder.Artifact.t()]
        }
end
