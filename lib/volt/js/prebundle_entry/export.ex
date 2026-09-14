defmodule Volt.JS.PrebundleEntry.Export do
  @moduledoc "Export descriptor used by synthetic prebundle entries."

  @type t :: %__MODULE__{
          default: String.t() | nil,
          members: [{String.t(), String.t()}] | nil,
          named_from: String.t() | nil,
          names: [String.t() | {String.t(), String.t()}] | nil,
          all_from: String.t() | nil
        }

  defstruct [:default, :members, :named_from, :names, :all_from]

  def default(expression), do: %__MODULE__{default: expression}
  def members(members), do: %__MODULE__{members: members}
  def named_from(specifier, names), do: %__MODULE__{named_from: specifier, names: names}
  def all_from(specifier), do: %__MODULE__{all_from: specifier}
end
