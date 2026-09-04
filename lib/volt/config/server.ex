defmodule Volt.Config.Server do
  @moduledoc "Normalized development server configuration."

  defstruct prefix: Volt.Paths.prefix(),
            watch_dirs: [],
            reload_dirs: [],
            watch_ignored: [],
            hmr_timeout: 60_000,
            watch: true
end
