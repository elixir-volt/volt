import Config

config :vanilla_example,
  generators: [timestamp_type: :utc_datetime]

config :vanilla_example, VanillaExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: VanillaExampleWeb.ErrorHTML], layout: false],
  pubsub_server: VanillaExample.PubSub,
  live_view: [signing_salt: "volt-example"]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :volt,
  entry: "assets/js/app.ts",
  outdir: "priv/static/assets",
  root: "assets",
  sources: ["**/*.{js,ts}"],
  target: :es2020,
  minify: false,
  hash: false,
  resolve_dirs: ["node_modules", "deps"],
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts}"}
    ]
  ]

config :volt, :format,
  semi: false,
  single_quote: true

config :volt, :lint, plugins: [:typescript]

import_config "#{config_env()}.exs"
