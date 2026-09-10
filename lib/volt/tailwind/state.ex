defmodule Volt.Tailwind.State do
  @moduledoc false

  @enforce_keys [:key, :sources]
  defstruct [
    :key,
    :scanner,
    :last_css,
    :sources,
    :compilation,
    :runtime,
    :context,
    configured_sources: [],
    dependencies: []
  ]
end
