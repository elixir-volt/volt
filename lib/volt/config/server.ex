defmodule Volt.Config.Server do
  @moduledoc "Normalized development server configuration."

  defstruct prefix: Volt.Paths.prefix(), watch_dirs: []
end
