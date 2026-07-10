import Config

config :volt, :server, watch: false

config :volt,
       :lint,
       Keyword.merge(Application.get_env(:volt, :lint, []),
         tsgolint: "node_modules/.bin/tsgolint",
         cwd: File.cwd!()
       )
