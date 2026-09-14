defmodule Volt.Tailwind.Context do
  @moduledoc "A compiler handle tied to one QuickBEAM runtime generation."
  @enforce_keys [:runtime, :id]
  defstruct [:runtime, :id]
end
