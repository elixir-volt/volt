import Config

config :volt,
  root: "priv/ts",
  entry: "priv/ts/dev/hmr-client.ts"

config :volt, :lint,
  tsgolint: "node_modules/.bin/tsgolint",
  cwd: File.cwd!()
