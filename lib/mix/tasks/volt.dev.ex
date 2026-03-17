defmodule Mix.Tasks.Volt.Dev do
  @shortdoc "Start the Volt dev watcher with HMR"
  @moduledoc """
  Start the Volt file watcher for development.

  Watches source files, recompiles on change, rebuilds Tailwind CSS
  when templates change, and pushes HMR updates over WebSocket.

      mix volt.dev

  ## Options

    * `--root` — asset source directory (default: `"assets"`)
    * `--watch-dir` — additional directory to watch (repeatable, e.g. `lib/`)
    * `--tailwind` — enable Tailwind CSS rebuilds
    * `--tailwind-css` — custom Tailwind input CSS file
    * `--tailwind-outdir` — directory to write rebuilt CSS (default: `"priv/static/assets/css"`)
    * `--target` — JS target (default: `"es2020"`)
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

    tailwind = Keyword.get(parsed, :tailwind, false)
    watch_dirs = Keyword.get_values(parsed, :watch_dir)
    watch_dirs = if tailwind and watch_dirs == [], do: ["lib/"], else: watch_dirs

    if tailwind do
      initial_build(parsed)
    end

    opts = [
      root: Keyword.get(parsed, :root, "assets"),
      watch_dirs: watch_dirs,
      tailwind: tailwind,
      tailwind_css: parsed[:tailwind_css],
      tailwind_outdir: Keyword.get(parsed, :tailwind_outdir, "priv/static/assets/css"),
      target: Keyword.get(parsed, :target, "es2020")
    ]

    {:ok, _pid} = Volt.Watcher.start_link(opts)

    Mix.shell().info("[Volt] Watching #{opts[:root]}...")

    if tailwind do
      Mix.shell().info("[Volt] Tailwind CSS enabled (watching #{Enum.join(watch_dirs, ", ")})")
    end

    unless iex_running?() do
      Process.sleep(:infinity)
    end
  end

  defp initial_build(parsed) do
    sources = [
      %{base: "lib/", pattern: "**/*.{ex,heex,eex}"},
      %{base: "assets/", pattern: "**/*.{vue,ts,tsx,js,jsx}"}
    ]

    css_input =
      case parsed[:tailwind_css] do
        nil -> nil
        path -> File.read!(path)
      end

    case Volt.Tailwind.build(sources: sources, css: css_input) do
      {:ok, css} ->
        outdir = Keyword.get(parsed, :tailwind_outdir, "priv/static/assets/css")
        File.mkdir_p!(outdir)
        File.write!(Path.join(outdir, "app.css"), css)
        Mix.shell().info("[Volt] Initial Tailwind build: #{format_size(byte_size(css))}")

      {:error, reason} ->
        Mix.shell().error("[Volt] Tailwind build failed: #{inspect(reason)}")
    end
  end

  @doc false
  defdelegate format_size(bytes), to: Volt.Format

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
