import Config

config :volt, :format,
  trailing_comma: :none,
  tab_width: 2,
  semi: false,
  single_quote: true,
  print_width: 100,
  arrow_parens: :always

config :volt, :lint,
  plugins: [:typescript, :import, :unicorn],
  rules: %{
    "no-unused-expressions" => :allow,
    "no-unused-vars" => :warn,
    "no-console" => :allow,
    "no-empty-function" => :deny,
    "eqeqeq" => :deny,
    "no-var" => :deny,
    "prefer-const" => :deny,
    "typescript/no-explicit-any" => :warn,
    "typescript/no-non-null-assertion" => :warn,
    "typescript/consistent-type-imports" => :deny,
    "typescript/no-floating-promises" => :deny,
    "typescript/no-misused-promises" => :deny,
    "import/no-cycle" => :deny,
    "import/no-self-import" => :deny,
    "import/no-duplicates" => :deny,
    "import/no-mutable-exports" => :deny,
    "unicorn/no-instanceof-array" => :deny,
    "unicorn/no-typeof-undefined" => :deny,
    "unicorn/no-nested-ternary" => :deny,
    "unicorn/no-useless-fallback-in-spread" => :deny,
    "unicorn/no-unnecessary-await" => :deny,
    "unicorn/prefer-string-starts-ends-with" => :deny
  }

import_config "#{config_env()}.exs"
