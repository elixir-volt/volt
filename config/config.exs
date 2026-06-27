import Config

config :volt, :format,
  trailing_comma: :none,
  tab_width: 2,
  semi: false,
  single_quote: true,
  print_width: 100,
  arrow_parens: :always

config :volt, :lint,
  rules: %{
    "no-unused-expressions" => :allow
  }

import_config "#{config_env()}.exs"
