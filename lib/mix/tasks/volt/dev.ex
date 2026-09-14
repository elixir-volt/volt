defmodule Mix.Tasks.Volt.Dev do
  @shortdoc "Start the Volt dev watcher with HMR"
  @moduledoc """
  Start the Volt file watcher for development.

  Reads configuration from `config :volt` and `config :volt, :server`.
  Pass a profile name as the first argument to use a named profile.
  CLI flags override config values.

      mix volt.dev
      mix volt.dev my_app_web

  ## Options

    * `--root` — asset source directory (default from config or `"assets"`)
    * `--watch-dir` — additional directory to watch for Tailwind scanning (repeatable)
    * `--reload-dir` — additional directory whose changes trigger a full browser reload (repeatable)
    * `--watch-ignore` — path or glob pattern excluded from watcher events (repeatable)
    * `--tailwind` — enable Tailwind CSS rebuilds
    * `--tailwind-css` — custom Tailwind input CSS file
    * `--tailwind-outdir` — directory to write rebuilt CSS (default: `"priv/static/assets/css"`)
    * `--target` — JS target (default: `es2020`)
  """
  use Mix.Task

  alias Volt.Dev
  alias Volt.Config
  alias Volt.Paths

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          root: :string,
          watch_dir: [:string, :keep],
          reload_dir: [:string, :keep],
          watch_ignore: [:string, :keep],
          tailwind: :boolean,
          tailwind_css: :string,
          tailwind_outdir: :string,
          target: :string
        ]
      )

    profile = parse_profile(argv)
    config = Config.build(profile)
    server_config = Config.server(profile)
    tailwind_config = Config.tailwind(profile)

    root = Keyword.get(parsed, :root) || to_string(config.root)
    target = Keyword.get(parsed, :target) || to_string(config.target)

    tailwind_root =
      tailwind_config
      |> Keyword.put(:css, Keyword.get(parsed, :tailwind_css) || tailwind_config[:css])
      |> Volt.Config.Tailwind.new()

    tailwind? =
      Keyword.get(
        parsed,
        :tailwind,
        not is_nil(parsed[:tailwind_css]) or Volt.Config.Tailwind.enabled?(tailwind_config)
      )

    cli_watch_dirs = Keyword.get_values(parsed, :watch_dir)
    cli_reload_dirs = Keyword.get_values(parsed, :reload_dir)
    cli_watch_ignored = Keyword.get_values(parsed, :watch_ignore)

    watch_dirs =
      case cli_watch_dirs do
        [] -> server_config.watch_dirs
        list -> list
      end

    reload_dirs =
      case cli_reload_dirs do
        [] -> server_config.reload_dirs
        list -> list
      end

    watch_ignored =
      case cli_watch_ignored do
        [] -> server_config.watch_ignored
        list -> list
      end

    watch_dirs = if tailwind? and watch_dirs == [], do: [Paths.lib()], else: watch_dirs

    tailwind_css = tailwind_root.css

    opts = [
      id: profile || :default,
      root: root,
      watch_dirs: watch_dirs,
      reload_dirs: reload_dirs,
      watch_ignored: watch_ignored,
      tailwind_key: tailwind_key(profile, tailwind_root),
      tailwind: tailwind?,
      tailwind_css: tailwind_css,
      tailwind_name: tailwind_root.name,
      tailwind_sources: tailwind_root.sources,
      tailwind_url: tailwind_root.dev_url,
      tailwind_sink: Keyword.get(parsed, :tailwind_outdir, Paths.static_css()),
      target: target
    ]

    {:ok, _pid} = Dev.start(opts)

    Mix.shell().info("[Volt] Watching #{opts[:root]}...")

    if tailwind? do
      Mix.shell().info("[Volt] Tailwind CSS enabled (watching #{Enum.join(watch_dirs, ", ")})")
    end

    if reload_dirs != [] do
      Mix.shell().info("[Volt] Full reload dirs: #{Enum.join(reload_dirs, ", ")}")
    end

    if watch_ignored != [] do
      Mix.shell().info("[Volt] Ignored watcher paths: #{Enum.join(watch_ignored, ", ")}")
    end

    unless iex_running?() do
      session = Dev.session_identity(opts)

      try do
        Process.sleep(:infinity)
      after
        Dev.stop(session)
      end
    end
  end

  defp tailwind_key(profile, root),
    do: {:profile, profile || :default, root.css || root.name}

  defp parse_profile(args), do: Volt.Config.Profile.from_args(args)

  @dialyzer {:nowarn_function, iex_running?: 0}
  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
