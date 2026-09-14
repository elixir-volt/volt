defmodule Volt.Builder.Asset do
  @moduledoc "Metadata for one asset emitted by a production build."

  @enforce_keys [:src, :file]
  defstruct [:src, :file]

  @type t :: %__MODULE__{src: String.t(), file: String.t()}
end
