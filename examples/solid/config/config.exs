import Config

config :solid_example,
  generators: [timestamp_type: :utc_datetime]

config :solid_example, SolidExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: SolidExampleWeb.ErrorHTML], layout: false],
  pubsub_server: SolidExample.PubSub,
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
  resolve_dirs: ["node_modules", "deps"],
  plugins: [Volt.Plugin.Solid],
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx}"}
    ]
  ]

config :volt, :format,
  semi: false,
  single_quote: true

config :volt, :lint,
  plugins: [:typescript],
  tsgolint: System.find_executable("tsgolint"),
  rules: %{
    "correctness" => :deny,
    "typescript/no-floating-promises" => :warn
  }

import_config "#{config_env()}.exs"
