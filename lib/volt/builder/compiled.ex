defmodule Volt.Builder.Compiled do
  @moduledoc "Compiled modules and prepared binary assets before bundling."

  defstruct scripts: [], styles: [], assets: [], artifacts: []
end
