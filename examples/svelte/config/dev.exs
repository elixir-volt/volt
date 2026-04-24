import Config

config :svelte_example, SvelteExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "volt-example-secret-key-base-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
  watchers: []

config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/", "assets/"]
