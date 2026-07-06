defmodule Volt.Builder.Bundle do
  @moduledoc """
  In-memory JavaScript bundle returned from `Volt.Builder.bundle/1`.

  Unlike `Volt.Builder.Result`, which describes files written to disk by
  `Volt.Builder.build/1`, this struct carries executable bundle contents and
  metadata for callers that need Volt's normal build graph without production
  output files.
  """

  @enforce_keys [:entry, :code, :files]
  defstruct [:entry, :code, :sourcemap, :files, css: nil, assets: []]

  @type t :: %__MODULE__{
          entry: Path.t(),
          code: String.t(),
          sourcemap: String.t() | nil,
          files: [Path.t()],
          css: String.t() | nil,
          assets: [term()]
        }
end
