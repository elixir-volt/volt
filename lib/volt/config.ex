defmodule Volt.Config do
  @moduledoc """
  Read Volt configuration from application environment.

  All config lives under the `:volt` application key in `config/config.exs`:

      # config/config.exs
      config :volt,
        entry: "assets/js/app.ts",
        target: :es2020,
        external: ~w(phoenix phoenix_html phoenix_live_view),
        aliases: %{
          "@" => "assets/src",
          "@components" => "assets/src/components"
        },
        plugins: [],
        tailwind: [
          css: "assets/css/app.css",
          sources: [
            %{base: "lib/", pattern: "**/*.{ex,heex}"},
            %{base: "assets/", pattern: "**/*.{vue,ts,tsx}"}
          ]
        ]

      # config/dev.exs
      config :volt, :server,
        prefix: "/assets",
        watch_dirs: ["lib/"]

  CLI flags and plug options override config values.
  """

  @defaults %{
    entry: "assets/js/app.ts",
    outdir: "priv/static/assets",
    target: :es2020,
    minify: true,
    sourcemap: true,
    hash: true,
    code_splitting: true,
    mode: :production,
    external: [],
    aliases: %{},
    plugins: [],
    resolve_dirs: [],
    root: "assets",
    import_source: nil,
    vapor: false
  }

  @server_defaults %{
    prefix: "/assets",
    watch_dirs: []
  }

  @doc """
  Read the full build config, merged with defaults.

  `overrides` (from CLI flags or function opts) take precedence
  over app env, which takes precedence over defaults.
  """
  @spec build(keyword()) :: map()
  def build(overrides \\ []) do
    app_env = Application.get_all_env(:volt) |> Keyword.drop([:tailwind, :server])

    @defaults
    |> Map.merge(Map.new(app_env))
    |> Map.merge(Map.new(overrides, fn {k, v} -> {k, v} end))
    |> maybe_wrap_entry()
  end

  @doc """
  Read dev server config, merged with defaults.
  """
  @spec server(keyword()) :: map()
  def server(overrides \\ []) do
    app_env = Application.get_env(:volt, :server, [])

    @server_defaults
    |> Map.merge(Map.new(app_env))
    |> Map.merge(Map.new(overrides))
  end

  @doc """
  Read Tailwind config.
  """
  @spec tailwind() :: keyword()
  def tailwind do
    Application.get_env(:volt, :tailwind, [])
  end

  defp maybe_wrap_entry(%{entry: entries} = config) when is_list(entries), do: config
  defp maybe_wrap_entry(config), do: config
end
