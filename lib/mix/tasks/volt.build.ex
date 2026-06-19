defmodule Mix.Tasks.Volt.Build do
  @shortdoc "Build production frontend assets"
  @moduledoc """
  Build production frontend assets.

      mix volt.build
      mix volt.build my_app_web

  Reads configuration from `config :volt` in your config files.
  Pass a profile name as the first argument to use a named profile.
  CLI flags override config values.

  ## Options

    * `--entry` — entry file (repeatable, default from config or `"assets/js/app.ts"`)
    * `--outdir` — output directory (default: `"priv/static/assets"`)
    * `--public-dir` — optional Vite-style public directory copied to the static root as-is
    * `--asset-url-prefix` — public URL prefix for production asset references (default: `"/assets"`)
    * `--target` — JS target (default: `es2020`)
    * `--no-minify` — skip minification
    * `--sourcemap false` — skip source map generation
    * `--sourcemap hidden` — write `.map` files but omit `sourceMappingURL` comment
    * `--resolve-dir` — additional directory for bare specifier resolution (repeatable)
    * `--external` — specifier to exclude from bundle (repeatable)
    * `--name` — output base name (default: derived from entry filename)
    * `--no-hash` — stable filenames (no content hash)
    * `--no-code-splitting` — disable chunk splitting
    * `--no-tree-shaking` — preserve unused exports
    * `--mode` — build mode for env variables (default: `"production"`)
    * `--format` — output format: `iife`, `esm`, or `cjs` (default from config)
    * `--tailwind` — build Tailwind CSS
    * `--tailwind-css` — custom Tailwind input CSS file
    * `--tailwind-source` — source directory for Tailwind scanning (repeatable)
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("compile")
    Application.ensure_all_started(:volt)

    {parsed, argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          entry: [:string, :keep],
          outdir: :string,
          public_dir: :string,
          asset_url_prefix: :string,
          target: :string,
          minify: :boolean,
          sourcemap: :string,
          name: :string,
          hash: :boolean,
          mode: :string,
          format: :string,
          resolve_dir: [:string, :keep],
          external: [:string, :keep],
          code_splitting: :boolean,
          tree_shaking: :boolean,
          tailwind: :boolean,
          tailwind_css: :string,
          tailwind_source: [:string, :keep]
        ]
      )

    profile = parse_profile(argv)
    config = Volt.Config.build(profile)
    tailwind_config = Volt.Config.tailwind(profile)

    cli_entries = Keyword.get_values(parsed, :entry)
    cli_resolve_dirs = Keyword.get_values(parsed, :resolve_dir)
    cli_externals = Keyword.get_values(parsed, :external)

    outdir = Keyword.get(parsed, :outdir) || to_string(config.outdir)
    minify = Keyword.get(parsed, :minify, config.minify)

    tailwind? =
      Keyword.get(parsed, :tailwind) ||
        (tailwind_config != [] and Keyword.get(parsed, :tailwind, true))

    if tailwind? do
      build_tailwind(parsed, tailwind_config, outdir, minify, config.hash, config.root)
    end

    entries =
      case cli_entries do
        [] -> List.wrap(config.entry)
        list -> list
      end

    resolve_dirs =
      case cli_resolve_dirs do
        [] -> config.resolve_dirs
        list -> list
      end

    externals =
      case cli_externals do
        [] -> config.external
        list -> list
      end

    opts = [
      entry: if(length(entries) == 1, do: hd(entries), else: entries),
      outdir: Path.join(outdir, "js"),
      public_dir: Keyword.get(parsed, :public_dir) || config.public_dir,
      asset_url_prefix: Keyword.get(parsed, :asset_url_prefix) || config.asset_url_prefix,
      target: Keyword.get(parsed, :target) || to_string(config.target),
      minify: minify,
      sourcemap: parse_sourcemap(Keyword.get(parsed, :sourcemap), config.sourcemap),
      resolve_dirs: resolve_dirs,
      external: externals,
      aliases: config.aliases,
      plugins: config.plugins,
      hash: Keyword.get(parsed, :hash, config.hash),
      mode: Keyword.get(parsed, :mode) || to_string(config.mode),
      format: parse_format(Keyword.get(parsed, :format), config.format),
      code_splitting: Keyword.get(parsed, :code_splitting, config.code_splitting),
      tree_shaking: Keyword.get(parsed, :tree_shaking, config.tree_shaking),
      chunks: config.chunks,
      env_prefix: config.env_prefix,
      import_source: config.import_source,
      module_types: config.module_types,
      root: config.root,
      name: parsed[:name]
    ]

    opts = if opts[:name], do: opts, else: Keyword.delete(opts, :name)

    build_js(opts)
  end

  defp build_js(opts) do
    Mix.shell().info("Building #{inspect(opts[:entry])}...")

    {us, result} = :timer.tc(fn -> Volt.Builder.build(opts) end)
    ms = div(us, 1000)

    case result do
      {:ok, %{js: js, css: css, manifest: manifest} = result} ->
        case js do
          %{path: path} ->
            Mix.shell().info("  #{Path.basename(path)}  #{format_file(path)}")

          _ ->
            :ok
        end

        if chunks = result[:chunks] do
          for chunk <- chunks, chunk.type != :entry do
            Mix.shell().info("  #{Path.basename(chunk.path)}  #{format_file(chunk.path)}")
          end
        end

        if css do
          Mix.shell().info("  #{Path.basename(css.path)}  #{format_file(css.path)}")
        end

        Mix.shell().info("  manifest.json  #{map_size(manifest)} entries")
        Mix.shell().info("Built in #{ms}ms")

      {:error, reason} ->
        Mix.shell().error("Build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp build_tailwind(parsed, tailwind_config, outdir, minify, config_hash, root) do
    cli_sources = Keyword.get_values(parsed, :tailwind_source)
    hash = Keyword.get(parsed, :hash, config_hash)

    sources =
      case cli_sources do
        [] ->
          tailwind_config[:sources] ||
            [
              %{base: Volt.Paths.lib(), pattern: "**/*.{ex,heex}"},
              %{base: Volt.Paths.assets_dir(), pattern: "**/*.{vue,ts,tsx,js,jsx}"}
            ]

        list ->
          Enum.map(list, &%{base: &1, pattern: "**/*"})
      end

    {css_input, css_base} =
      case Keyword.get(parsed, :tailwind_css) || tailwind_config[:css] do
        nil -> {nil, File.cwd!()}
        path -> {File.read!(path), Path.dirname(path)}
      end

    Mix.shell().info("Building Tailwind CSS...")

    {us, result} =
      :timer.tc(fn ->
        with {:ok, css} <-
               Volt.Tailwind.build(
                 sources: sources,
                 css: css_input,
                 css_base: css_base,
                 minify: false
               ) do
          Volt.Builder.Writer.build_style_entry(
            "app",
            css,
            Path.join(outdir, "css"),
            hash,
            nil,
            minify: minify,
            root: root
          )
        end
      end)

    ms = div(us, 1000)

    case result do
      {:ok, %{css: %{path: path, size: size}, manifest: manifest}} ->
        css_outdir = Path.dirname(path)
        Volt.Builder.Writer.write_manifest(css_outdir, manifest)

        Mix.shell().info("  #{Path.basename(path)}  #{Volt.Format.format_size(size)}")
        Mix.shell().info("  manifest.json  #{map_size(manifest)} entries")
        Mix.shell().info("Built Tailwind in #{ms}ms")

      {:error, reason} ->
        Mix.shell().error("Tailwind build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp parse_format(nil, default), do: default

  defp parse_format("iife", _default), do: :iife
  defp parse_format("esm", _default), do: :esm
  defp parse_format("cjs", _default), do: :cjs

  defp parse_format(_value, default), do: default

  defp parse_sourcemap("hidden", _default), do: :hidden
  defp parse_sourcemap("false", _default), do: false
  defp parse_sourcemap("true", _default), do: true
  defp parse_sourcemap(nil, default), do: default
  defp parse_sourcemap(_, default), do: default

  defp parse_profile(args), do: Volt.Config.Profile.from_args(args)

  defp format_file(path) do
    Volt.Format.format_with_gzip(File.read!(path))
  end
end
