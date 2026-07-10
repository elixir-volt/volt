defmodule Volt.DevServer.Config do
  @moduledoc "Resolved runtime configuration for the development server plug."

  defstruct root: nil,
            public_dir: nil,
            prefix: Volt.Paths.prefix(),
            target: "",
            import_source: nil,
            vapor: false,
            custom_renderer: false,
            plugins: [],
            aliases: %{},
            node_modules: nil,
            resolve_dirs: [],
            module_types: %{},
            define: %{},
            hmr_timeout: 60_000,
            watcher_opts: nil
end
