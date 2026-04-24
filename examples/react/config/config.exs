import Config

config :react_example,
  generators: [timestamp_type: :utc_datetime]

config :react_example, ReactExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: ReactExampleWeb.ErrorHTML], layout: false],
  pubsub_server: ReactExample.PubSub,
  live_view: [signing_salt: "volt-example"]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :volt,
  entry: "assets/js/app.tsx",
  outdir: "priv/static/assets",
  root: "assets",
  sources: ["**/*.{js,ts,jsx,tsx}"],
  target: :es2020,
  minify: false,
  hash: false,
  resolve_dirs: ["node_modules", "deps"],
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx}"}
    ]
  ],
  import_source: "react"

config :volt, :lint, plugins: [:typescript, :react]

import_config "#{config_env()}.exs"
