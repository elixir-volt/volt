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
    * `--name` — output base name (default: derived from entry filename)
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
          name: :string
        ]
      )

    opts = [
      entry: Keyword.get(parsed, :entry, "assets/js/app.ts"),
      outdir: Keyword.get(parsed, :outdir, "priv/static/assets"),
      target: Keyword.get(parsed, :target, "es2020"),
      minify: Keyword.get(parsed, :minify, true),
      sourcemap: Keyword.get(parsed, :sourcemap, true),
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

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"
end
