defmodule Volt.Builder.Context do
  @moduledoc "Shared build graph context used while collecting and compiling modules."

  defstruct node_modules: nil,
            resolve_dirs: [],
            aliases: %{},
            plugins: [],
            external: MapSet.new(),
            external_globals: %{},
            loaders: %{},
            module_types: %{},
            import_source: nil,
            target: "",
            define: %{},
            asset_url_prefix: Volt.Paths.prefix(),
            asset_outdir: nil,
            asset_root: nil
end
