defmodule Volt.Builder.OutputFile do
  @moduledoc "Metadata for one generated production output file."

  defstruct path: nil,
            size: 0,
            assets: [],
            chunk_id: nil,
            type: nil

  @type t :: %__MODULE__{
          path: String.t(),
          size: non_neg_integer(),
          assets: [term()],
          chunk_id: String.t() | nil,
          type: :entry | :chunk | nil
        }
end
