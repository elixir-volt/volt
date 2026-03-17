defmodule Mix.Tasks.Volt.Build do
  @shortdoc "Build production frontend assets"
  @moduledoc """
  Build production frontend assets.

      mix volt.build

  Reads configuration from `config :volt` in your config files.
  CLI flags override config values.

  ## Options

    * `--entry` — entry file (repeatable, default from config or `"assets/js/app.ts"`)
    * `--outdir` — output directory (default: `"priv/static/assets"`)
    * `--target` — JS target (default: `"es2020"`)
    * `--no-minify` — skip minification
    * `--no-sourcemap` — skip source map generation
    * `--resolve-dir` — additional directory for bare specifier resolution (repeatable)
    * `--external` — specifier to exclude from bundle (repeatable)
    * `--name` — output base name (default: derived from entry filename)
    * `--no-hash` — stable filenames (no content hash)
    * `--no-code-splitting` — disable chunk splitting
    * `--mode` — build mode for env variables (default: `"production"`)
    * `--tailwind` — build Tailwind CSS
    * `--tailwind-css` — custom Tailwind input CSS file
    * `--tailwind-source` — source directory for Tailwind scanning (repeatable)
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          entry: [:string, :keep],
          outdir: :string,
          target: :string,
          minify: :boolean,
          sourcemap: :boolean,
          name: :string,
          hash: :boolean,
          mode: :string,
          resolve_dir: [:string, :keep],
          external: [:string, :keep],
          code_splitting: :boolean,
          tailwind: :boolean,
          tailwind_css: :string,
          tailwind_source: [:string, :keep]
        ]
      )

    config = Volt.Config.build()
    tailwind_config = Volt.Config.tailwind()

    cli_entries = Keyword.get_values(parsed, :entry)
    cli_resolve_dirs = Keyword.get_values(parsed, :resolve_dir)
    cli_externals = Keyword.get_values(parsed, :external)

    outdir = Keyword.get(parsed, :outdir) || to_string(config.outdir)
    minify = Keyword.get(parsed, :minify, config.minify)

    tailwind? =
      Keyword.get(parsed, :tailwind) ||
        (tailwind_config != [] and Keyword.get(parsed, :tailwind, true))

    if tailwind? do
      build_tailwind(parsed, tailwind_config, outdir, minify)
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
      target: Keyword.get(parsed, :target) || to_string(config.target),
      minify: minify,
      sourcemap: Keyword.get(parsed, :sourcemap, config.sourcemap),
      resolve_dirs: resolve_dirs,
      external: externals,
      aliases: config.aliases,
      plugins: config.plugins,
      hash: Keyword.get(parsed, :hash, config.hash),
      mode: Keyword.get(parsed, :mode) || to_string(config.mode),
      code_splitting: Keyword.get(parsed, :code_splitting, config.code_splitting),
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
          %{path: path, size: size} ->
            Mix.shell().info("  #{Path.basename(path)}  #{format_size(size)}")

          _ ->
            :ok
        end

        if chunks = result[:chunks] do
          for chunk <- chunks, chunk.type != :entry do
            Mix.shell().info("  #{Path.basename(chunk.path)}  #{format_size(chunk.size)}")
          end
        end

        if css do
          Mix.shell().info("  #{Path.basename(css.path)}  #{format_size(css.size)}")
        end

        Mix.shell().info("  manifest.json  #{map_size(manifest)} entries")
        Mix.shell().info("Built in #{ms}ms")

      {:error, reason} ->
        Mix.shell().error("Build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp build_tailwind(parsed, tailwind_config, outdir, minify) do
    cli_sources = Keyword.get_values(parsed, :tailwind_source)
    hash = Keyword.get(parsed, :hash, true)

    sources =
      case cli_sources do
        [] ->
          tailwind_config[:sources] ||
            [
              %{base: "lib/", pattern: "**/*.{ex,heex}"},
              %{base: "assets/", pattern: "**/*.{vue,ts,tsx,js,jsx}"}
            ]

        list ->
          Enum.map(list, &%{base: &1, pattern: "**/*"})
      end

    css_input =
      case Keyword.get(parsed, :tailwind_css) || tailwind_config[:css] do
        nil -> nil
        path -> File.read!(path)
      end

    Mix.shell().info("Building Tailwind CSS...")

    {us, result} =
      :timer.tc(fn -> Volt.Tailwind.build(sources: sources, css: css_input, minify: minify) end)

    ms = div(us, 1000)

    case result do
      {:ok, css} ->
        css_outdir = Path.join(outdir, "css")
        File.mkdir_p!(css_outdir)
        name = "app"

        filename =
          if hash,
            do: "#{name}-#{content_hash(css)}.css",
            else: "#{name}.css"

        path = Path.join(css_outdir, filename)
        File.write!(path, css)

        Mix.shell().info("  #{filename}  #{format_size(byte_size(css))}")
        Mix.shell().info("Built Tailwind in #{ms}ms")

      {:error, reason} ->
        Mix.shell().error("Tailwind build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp content_hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  defdelegate format_size(bytes), to: Volt.Format
end
