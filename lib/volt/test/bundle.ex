defmodule Volt.Test.Bundle do
  @moduledoc """
  Executable JavaScript bundle for a Volt test file.

  This struct is owned by the Elixir side of the test runner. JavaScript runner
  results remain plain JS-decoded maps; bundle metadata such as sourcemaps and
  source files stays here instead of being mixed into JS result maps.
  """

  @enforce_keys [:entry, :code, :files]
  defstruct [:entry, :code, :sourcemap, :files]

  @type t :: %__MODULE__{
          entry: Path.t(),
          code: String.t(),
          sourcemap: String.t() | nil,
          files: [Path.t()]
        }
end
