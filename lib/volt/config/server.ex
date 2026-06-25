defmodule Volt.Config.Server do
  @moduledoc "Normalized development server configuration."

  defstruct prefix: Volt.Paths.prefix(), watch_dirs: [], reload_dirs: [], hmr_timeout: 60_000
end
