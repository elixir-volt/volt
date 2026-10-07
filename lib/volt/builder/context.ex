defmodule Volt.Builder.Context do
  @moduledoc "Shared build graph context used while collecting and compiling modules."

  defstruct node_modules: nil,
            resolve_dirs: [],
            package_scopes: [],
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

  @type t :: %__MODULE__{
          node_modules: Path.t() | nil,
          resolve_dirs: [Path.t()],
          package_scopes: list(),
          aliases: %{String.t() => String.t()},
          plugins: [module() | {module(), keyword()}],
          external: MapSet.t(String.t()),
          external_globals: %{String.t() => String.t()},
          loaders: map(),
          module_types: map(),
          import_source: String.t() | nil,
          target: String.t(),
          define: map(),
          asset_url_prefix: String.t(),
          asset_outdir: Path.t() | nil,
          asset_root: Path.t() | nil
        }
end
