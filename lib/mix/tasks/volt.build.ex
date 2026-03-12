defmodule Mix.Tasks.Volt.Build do
  @shortdoc "Build production frontend assets"
  @moduledoc """
  Build production frontend assets.

      mix volt.build

  ## Options

    * `--entry` — entry file (default: `"assets/js/app.ts"`)
    * `--outdir` — output directory (default: `"priv/static/assets"`)
    * `--target` — JS target (default: `"es2020"`)
    * `--no-minify` — skip minification
    * `--no-sourcemap` — skip source map generation
    * `--resolve-dir` — additional directory for bare specifier resolution (repeatable, e.g. `deps`)
    * `--name` — output base name (default: derived from entry filename)
    * `--no-hash` — stable filenames (no content hash)
    * `--tailwind` — build Tailwind CSS (scans sources, compiles CSS)
    * `--tailwind-css` — custom Tailwind input CSS file (default: Tailwind base)
    * `--tailwind-source` — source directory for Tailwind scanning (repeatable)
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          entry: :string,
          outdir: :string,
          target: :string,
          minify: :boolean,
          sourcemap: :boolean,
          name: :string,
          hash: :boolean,
          resolve_dir: [:string, :keep],
          tailwind: :boolean,
          tailwind_css: :string,
          tailwind_source: [:string, :keep]
        ]
      )

    resolve_dirs = Keyword.get_values(parsed, :resolve_dir)
    minify = Keyword.get(parsed, :minify, true)
    outdir = Keyword.get(parsed, :outdir, "priv/static/assets")

    if Keyword.get(parsed, :tailwind, false) do
      build_tailwind(parsed, outdir, minify)
    end

    build_js(parsed, resolve_dirs, outdir, minify)
  end

  defp build_js(parsed, resolve_dirs, outdir, minify) do
    opts = [
      entry: Keyword.get(parsed, :entry, "assets/js/app.ts"),
      outdir: Path.join(outdir, "js"),
      target: Keyword.get(parsed, :target, "es2020"),
      minify: minify,
      sourcemap: Keyword.get(parsed, :sourcemap, true),
      resolve_dirs: resolve_dirs,
      hash: Keyword.get(parsed, :hash, true),
      name: parsed[:name]
    ]

    opts = if opts[:name], do: opts, else: Keyword.delete(opts, :name)

    Mix.shell().info("Building #{opts[:entry]}...")

    {us, result} = :timer.tc(fn -> Volt.Builder.build(opts) end)
    ms = div(us, 1000)

    case result do
      {:ok, %{js: js, css: css, manifest: manifest}} ->
        Mix.shell().info("  #{Path.basename(js.path)}  #{format_size(js.size)}")

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

  defp build_tailwind(parsed, outdir, minify) do
    tailwind_sources = Keyword.get_values(parsed, :tailwind_source)
    hash = Keyword.get(parsed, :hash, true)

    sources =
      if tailwind_sources == [] do
        [
          %{base: "lib/", pattern: "**/*.{ex,heex}"},
          %{base: "assets/", pattern: "**/*.{vue,ts,tsx,js,jsx}"}
        ]
      else
        Enum.map(tailwind_sources, &%{base: &1, pattern: "**/*"})
      end

    css_input =
      case Keyword.get(parsed, :tailwind_css) do
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

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"
end
