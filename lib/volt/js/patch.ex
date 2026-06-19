defmodule Volt.JS.Patch do
  @moduledoc "Small struct wrapper for source patches applied through OXC."

  defstruct [:start, :end, :change]

  @type t :: %__MODULE__{start: non_neg_integer(), end: non_neg_integer(), change: iodata()}

  def new(start_pos, end_pos, change) do
    %__MODULE__{start: start_pos, end: end_pos, change: change}
  end

  def replace_selector(selector, change) do
    new(Map.fetch!(selector, :start), Map.fetch!(selector, :end), change)
  end

  def selector_specifier(selector), do: Map.fetch!(selector, :specifier)

  def apply(source, patches) do
    OXC.patch_string(source, Enum.map(patches, &Map.from_struct/1))
  end
end
