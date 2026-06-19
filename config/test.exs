import Config

config :volt, :lint,
  tsgolint: "node_modules/.bin/tsgolint",
  cwd: File.cwd!()
