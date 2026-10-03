defmodule Volt.Config do
  @moduledoc """
  Read Volt configuration from application environment.

  ## Flat config (single app)

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

  ## Named profiles (umbrella / multi-web apps)

  Use a named profile to configure multiple independent Volt instances:

      # config/config.exs
      config :volt, :my_app_web,
        entry: "apps/my_app_web/assets/js/app.js",
        outdir: "apps/my_app_web/priv/static/assets",
        tailwind: [
          css: "apps/my_app_web/assets/css/app.css",
          sources: [
            %{base: "apps/my_app_web/lib/", pattern: "**/*.{ex,heex,eex}"}
          ]
        ],
        server: [watch_dirs: ["apps/my_app_web/lib/"]]

  Pass the profile name to Mix tasks and the plug:

      mix volt.build my_app_web --tailwind
      mix volt.dev my_app_web --tailwind

      plug Volt.DevServer, root: "assets", profile: :my_app_web

  CLI flags and plug options override config values.

  ## Source maps

  The `:sourcemap` option controls production source map generation:

    * `true` — write `.map` files and append `//# sourceMappingURL` (default)
    * `:hidden` — write `.map` files but omit the URL comment (for error tracking services)
    * `false` — no source maps

  ## Tree shaking

  Production builds tree-shake JavaScript by default. Set `tree_shaking: false`
  to preserve unused exports.

  ## Environment variables

  The `:env_prefix` option controls which `.env` variables are exposed to
  client code through `import.meta.env`. It defaults to `"VOLT_"` and accepts a
  string or list of strings.

  ## Asset URL prefix

  The `:asset_url_prefix` option controls the public URL prefix emitted for
  production asset references in JavaScript and CSS. It defaults to `"/assets"`,
  matching Phoenix's conventional `priv/static/assets` mount.

  ## Manual chunks

  The `:chunks` option controls manual chunk splitting:

      config :volt,
        chunks: %{
          "vendor" => ["vue", "vue-router", "pinia"],
          "ui" => ["assets/src/components"]
        }

  Bare specifiers match package names in node_modules. Path patterns match
  against the full module path.

  ## tsconfig.json paths

  Volt automatically reads `compilerOptions.paths` from `tsconfig.json` in
  the project root and merges them into aliases. Explicitly configured
  aliases take precedence over tsconfig paths.
  """

  @defaults %Volt.Config.Build{}
  @build_keys @defaults |> Map.from_struct() |> Map.keys()

  @server_defaults %Volt.Config.Server{}

  @doc """
  Read the full build config, merged with defaults.

  Accepts an optional profile atom as the first argument. When given, reads
  from `Application.get_env(:volt, profile)` and merges it on top of flat
  config and defaults.

  `overrides` (from CLI flags or function opts) take precedence over all
  config sources.

  Automatically reads `compilerOptions.paths` from `tsconfig.json` and
  merges them into aliases. Explicit aliases override tsconfig paths.
  """
  @spec build(atom() | keyword()) :: map()
  def build(profile_or_overrides \\ [])

  def build(profile) when is_atom(profile) do
    build(profile, [])
  end

  def build(overrides) when is_list(overrides) do
    build(nil, overrides)
  end

  @spec build(atom() | nil, keyword()) :: map()
  def build(profile, overrides) do
    flat_env = Application.get_all_env(:volt) |> Keyword.take(@build_keys)

    profile_env =
      if profile do
        Application.get_env(:volt, profile, []) |> Keyword.take(@build_keys)
      else
        []
      end

    reject_formatter_options!(flat_env[:format])
    reject_formatter_options!(profile_env[:format])

    config =
      @defaults
      |> Map.from_struct()
      |> Map.merge(Map.new(flat_env))
      |> Map.merge(Map.new(profile_env))
      |> Map.merge(overrides |> Keyword.take(@build_keys) |> Map.new())
      |> then(&struct!(Volt.Config.Build, &1))

    tsconfig_paths = Volt.JS.TSConfig.discover_paths()
    %{config | aliases: Map.merge(tsconfig_paths, config.aliases)}
  end

  @doc false
  def reject_formatter_options!(format) when is_list(format) do
    raise ArgumentError, """
    formatter options are no longer read from `config :volt, :format`, which now \
    only holds the build output format (`:iife`, `:esm`, or `:cjs`).

    Move them to the `:volt` key of .formatter.exs:

        [
          plugins: [Volt.Formatter],
          volt: #{inspect(format)}
        ]
    """
  end

  def reject_formatter_options!(_format), do: :ok

  @doc """
  Read dev server config, merged with defaults.

  When a profile is given, reads the `:server` key from within that profile's
  config, falling back to the global `:server` config.
  """
  @spec server(atom() | keyword()) :: map()
  def server(profile_or_overrides \\ [])

  def server(profile) when is_atom(profile) do
    server(profile, [])
  end

  def server(overrides) when is_list(overrides) do
    server(nil, overrides)
  end

  @spec server(atom() | nil, keyword()) :: map()
  def server(profile, overrides) do
    global_env = Application.get_env(:volt, :server, [])

    profile_env =
      if profile do
        Application.get_env(:volt, profile, []) |> Keyword.get(:server, [])
      else
        []
      end

    server_keys = @server_defaults |> Map.from_struct() |> Map.keys()

    @server_defaults
    |> Map.from_struct()
    |> Map.merge(global_env |> Keyword.take(server_keys) |> Map.new())
    |> Map.merge(profile_env |> Keyword.take(server_keys) |> Map.new())
    |> Map.merge(overrides |> Keyword.take(server_keys) |> Map.new())
    |> then(&struct!(Volt.Config.Server, &1))
  end

  @doc """
  Read Tailwind config.

  When a profile is given, reads the `:tailwind` key from within that
  profile's config, falling back to the global `:tailwind` config.
  """
  @spec tailwind(atom() | nil) :: keyword()
  def tailwind(profile \\ nil)

  def tailwind(nil), do: Application.get_env(:volt, :tailwind, [])

  def tailwind(profile) when is_atom(profile) do
    profile_config = Application.get_env(:volt, profile, [])
    Keyword.get(profile_config, :tailwind) || Application.get_env(:volt, :tailwind, [])
  end
end
