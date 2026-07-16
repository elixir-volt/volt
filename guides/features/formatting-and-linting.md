# Formatting and Linting

## Formatting

`Volt.Formatter` is a `mix format` plugin — JS/TS files are formatted alongside Elixir using oxfmt via NIF (~30× faster than Prettier).

Add to `.formatter.exs`:

```elixir
[
  plugins: [Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "assets/**/*.{js,ts,jsx,tsx}"
  ]
]
```

Or format manually:

```bash
mix volt.js.format
```

### Configuration

```elixir
config :volt, :format,
  print_width: 100,
  semi: false,
  single_quote: true,
  trailing_comma: :none,
  arrow_parens: :always
```

All [oxfmt options](https://hexdocs.pm/oxc/OXC.Format.html) are supported. Falls back to `.oxfmtrc.json` if no Elixir config is set.

`:root`, `:sources`, and `:ignore` may also be set under `config :volt, :format` to override the build source set for formatting only.

## Linting

Lint JS/TS assets using oxlint via NIF — 650+ rules, no Node.js required:

```bash
mix volt.lint
mix volt.lint --plugin react --plugin typescript
```

Available plugins: `react`, `typescript`, `unicorn`, `import`, `jsdoc`, `jest`, `vitest`, `jsx_a11y`, `nextjs`, `react_perf`, `promise`, `node`, `vue`, `oxc`.

### Configuration

```elixir
config :volt, :lint,
  sources: ["priv/ts/**/*.ts", "test/javascript/**/*.mjs"],
  ignore: ["test/javascript/fixtures/**"],
  env: [:browser, :node, :mocha],
  globals: %{"AppRuntime" => :readonly},
  plugins: [:typescript],
  rules: %{
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-explicit-any" => :warn
  }
```

Lint-specific `:root`, `:sources`, and `:ignore` values override the build source set without changing which files the formatter checks. This is useful when canonical fixtures must be linted but retain their original formatting.

### Custom Rules

Custom lint rules can be written in Elixir using the `OXC.Lint.Rule` behaviour — see the [oxc docs](https://hexdocs.pm/oxc/OXC.Lint.Rule.html).

## Combined Check

Check formatting and lint in one command (useful for CI):

```bash
mix volt.js.check
```

For TypeScript projects, run type-aware rules through `tsgolint` headless mode:

```bash
mix volt.js.check --type-aware
mix volt.js.check --type-aware --type-check
```

`--type-aware` also checks JavaScript-like scripts embedded in framework component files when the enabled plugin exposes them. Volt's built-in Vue and Svelte plugins expose `<script>` blocks as virtual `.js`, `.ts`, or `.tsx` modules for `tsgolint`, then map diagnostics back to the original `.vue` or `.svelte` file. Component templates are still handled by the normal syntax lint/format path; they are not passed to `tsgolint`.

Configure the executable when it is not on `PATH`:

```elixir
config :volt, :lint,
  tsgolint: "./node_modules/.bin/tsgolint",
  rules: %{
    "correctness" => :deny,
    "typescript/consistent-type-imports" => :deny,
    "typescript/no-floating-promises" => :deny,
    "typescript/no-misused-promises" => :deny
  }
```

Volt keeps the Oxlint-style rule shape: configure normal and type-aware rules together under `:rules`. When `--type-aware` is enabled, Volt still runs the normal syntax lint path and also invokes `tsgolint` for supported semantic TypeScript rules.

Exits with non-zero status on issues.
