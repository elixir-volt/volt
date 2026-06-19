defmodule Volt.Config.Build do
  @moduledoc "Normalized production build configuration."

  defstruct entry: Volt.Paths.entry(),
            outdir: Volt.Paths.static(),
            public_dir: false,
            target: :es2020,
            minify: true,
            sourcemap: true,
            hash: true,
            code_splitting: true,
            tree_shaking: true,
            format: :iife,
            mode: :production,
            env_prefix: "VOLT_",
            asset_url_prefix: Volt.Paths.prefix(),
            external: [],
            aliases: %{},
            chunks: %{},
            plugins: [],
            resolve_dirs: [],
            root: Volt.Paths.assets(),
            sources: ["**/*.{js,ts,jsx,tsx,vue}"],
            ignore: Volt.Paths.ignored_globs() ++ ["vendor/**"],
            import_source: nil,
            vapor: false,
            custom_renderer: false,
            module_types: %{}
end
