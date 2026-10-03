defmodule Volt.Builder.OutputContext do
  @moduledoc "Context passed to final JavaScript and CSS output rendering."

  defstruct plugins: [],
            external_set: MapSet.new(),
            external_globals: %{},
            external_imports: MapSet.new(),
            workers: %{},
            worker_results: %{}
end
