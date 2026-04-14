defmodule Mix.Tasks.Volt.Dev do
  @shortdoc "Start the Volt dev watcher with HMR"
  @moduledoc """
  Start the Volt file watcher for development.

  Reads configuration from `config :volt` and `config :volt, :server`.
  CLI flags override config values.

      mix volt.dev

  ## Options

    * `--root` — asset source directory (default from config or `"assets"`)
    * `--watch-dir` — additional directory to watch (repeatable)
    * `--tailwind` — enable Tailwind CSS rebuilds
    * `--tailwind-css` — custom Tailwind input CSS file
    * `--tailwind-outdir` — directory to write rebuilt CSS (default: `"priv/static/assets/css"`)
    * `--target` — JS target (default: `es2020`)
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          root: :string,
          watch_dir: [:string, :keep],
          tailwind: :boolean,
          tailwind_css: :string,
          tailwind_outdir: :string,
          target: :string
        ]
      )

    config = Volt.Config.build()
    server_config = Volt.Config.server()
    tailwind_config = Volt.Config.tailwind()

    root = Keyword.get(parsed, :root) || to_string(config.root)
    target = Keyword.get(parsed, :target) || to_string(config.target)

    tailwind? =
      Keyword.get(parsed, :tailwind) ||
        (tailwind_config != [] and Keyword.get(parsed, :tailwind, true))

    cli_watch_dirs = Keyword.get_values(parsed, :watch_dir)

    watch_dirs =
      case cli_watch_dirs do
        [] -> server_config.watch_dirs
        list -> list
      end

    watch_dirs = if tailwind? and watch_dirs == [], do: ["lib/"], else: watch_dirs

    tailwind_css = Keyword.get(parsed, :tailwind_css) || tailwind_config[:css]

    if tailwind? do
      initial_build(tailwind_config, tailwind_css, parsed)
    end

    opts = [
      root: root,
      watch_dirs: watch_dirs,
      tailwind: tailwind?,
      tailwind_css: tailwind_css,
      tailwind_outdir: Keyword.get(parsed, :tailwind_outdir, "priv/static/assets/css"),
      target: target
    ]

    {:ok, _pid} = Volt.Watcher.start_link(opts)

    Mix.shell().info("[Volt] Watching #{opts[:root]}...")

    if tailwind? do
      Mix.shell().info("[Volt] Tailwind CSS enabled (watching #{Enum.join(watch_dirs, ", ")})")
    end

    unless iex_running?() do
      Process.sleep(:infinity)
    end
  end

  defp initial_build(tailwind_config, tailwind_css, parsed) do
    sources =
      tailwind_config[:sources] ||
        [
          %{base: "lib/", pattern: "**/*.{ex,heex,eex}"},
          %{base: "assets/", pattern: "**/*.{vue,ts,tsx,js,jsx}"}
        ]

    css_input =
      case tailwind_css do
        nil -> nil
        path -> File.read!(path)
      end

    case Volt.Tailwind.build(sources: sources, css: css_input) do
      {:ok, css} ->
        outdir = Keyword.get(parsed, :tailwind_outdir, "priv/static/assets/css")
        File.mkdir_p!(outdir)
        File.write!(Path.join(outdir, "app.css"), css)

        Mix.shell().info(
          "[Volt] Initial Tailwind build: #{Volt.Format.format_size(byte_size(css))}"
        )

      {:error, reason} ->
        Mix.shell().error("[Volt] Tailwind build failed: #{inspect(reason)}")
    end
  end

  @dialyzer {:nowarn_function, iex_running?: 0}
  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
