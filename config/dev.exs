import Config

config :volt,
  root: "priv/ts",
  entry: "priv/ts/client/hmr.ts"

config :volt,
       :lint,
       Keyword.merge(Application.get_env(:volt, :lint, []),
         tsgolint: "node_modules/.bin/tsgolint",
         cwd: File.cwd!()
       )
