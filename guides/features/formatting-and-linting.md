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

Formatter options live under the `:volt` key of `.formatter.exs`, next to the plugin:

```elixir
[
  plugins: [Volt.Formatter],
  inputs: ["{config,lib,test}/**/*.{ex,exs}", "assets/**/*.{js,ts,jsx,tsx}"],
  volt: [
    print_width: 100,
    semi: false,
    single_quote: true,
    trailing_comma: :none,
    arrow_parens: :always
  ]
]
```

All [oxfmt options](https://hexdocs.pm/oxc/OXC.Format.html) are supported. Without a `:volt` key, options come from `.oxfmtrc.json` or `.prettierrc.json`. `mix format`, `mix volt.js.format`, and `mix volt.js.check` all read the same options.

`mix format` formats the files matched by `:inputs`. `mix volt.js.format` and `mix volt.js.check` use the build source set; `:root`, `:sources`, and `:ignore` under the `:volt` key override it for formatting only:

```elixir
[
  volt: [semi: false, sources: ["priv/ts/**/*.ts"], ignore: ["vendor/**"]]
]
```

> #### Upgrading {: .info}
>
> Formatter options used to live in `config :volt, :format`. That key now only holds the build output format (`:iife`, `:esm`, or `:cjs`), and a keyword list there raises with instructions to move it.

## Linting

Lint JS/TS assets using oxlint via NIF — 650+ rules, no Node.js required:

```bash
mix volt.lint
mix volt.lint --plugin react --plugin typescript
```

Plugin, environment, and global names are strings, as in an oxlint config file: `"react"`, `"unicorn"`, `"jsx-a11y"`, and so on. Unknown plugin names are reported as errors.

### Configuration

```elixir
config :volt, :lint,
  sources: ["priv/ts/**/*.ts", "test/javascript/**/*.mjs"],
  ignore: ["test/javascript/fixtures/**"],
  env: ["browser", "node", "mocha"],
  globals: %{"AppRuntime" => :readonly},
  plugins: ["typescript"],
  rules: %{
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-explicit-any" => :warn
  }
```

Lint-specific `:root`, `:sources`, and `:ignore` values override the build source set without changing which files the formatter checks. This is useful when canonical fixtures must be linted but retain their original formatting.

### Per-file overrides

Both `mix volt.lint` and `mix volt.js.check` resolve the same per-file settings:

```elixir
config :volt, :lint,
  root: ".",
  sources: ["assets/**/*.js", "scripts/**/*.js"],
  plugins: ["typescript", "unicorn"],
  env: ["browser"],
  rules: %{"correctness" => :deny, "unicorn/no-null" => :deny},
  overrides: [
    %{
      files: ["assets/colocated/**/*.js"],
      rules: %{"unicorn/filename-case" => :allow}
    },
    %{
      files: ["assets/js/dom.js"],
      rules: %{"unicorn/no-null" => :allow}
    },
    %{
      files: ["scripts/**/*.js"],
      env: %{"browser" => false, "node" => true},
      globals: %{"BuildContext" => :readonly}
    }
  ]
```

- `:files` is a non-empty list of globs relative to the lint root (`:root` under `:lint`, or the build root, which defaults to `assets`). Use `**/*.js` for nested files; `*.js` matches only the root level. Brace alternatives such as `**/*.{js,ts}` are supported.
- Overrides change settings for discovered files; they do not add files or change `:sources`/`:ignore`. Already-discovered dotfiles can match override globs.
- All matching overrides apply in declaration order. Later values win for each rule, environment or global; unrelated inherited entries remain intact. Rule severities are `:allow`, `:warn`, or `:deny`.
- Environment lists enable names; maps can enable or disable them. Set an inherited global to `:off` to remove it, or use `:readonly`/`:writable` to set its access.
- Override entries may be maps or keyword lists and support only `:files`, `:rules`, `:env`, and `:globals`. Plugins and custom rules remain run-wide; `mix volt.lint --plugin` retains its precedence over configured plugins.

Type-aware checks group files by their effective TypeScript rules. Vue/Svelte script overrides match the original component path, not the generated virtual filename. Every group retains the complete set of extracted script sources, and diagnostics are mapped back to component paths. Environment/global overrides apply to syntax linting, not to TypeScript's project-level compiler configuration. File discovery and formatting settings are unchanged.

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

With `--type-aware`, categories also select type-aware rules from the enabled plugins. For example, `"correctness" => :deny` with `plugins: ["typescript"]` runs `typescript/no-floating-promises`. Individual rule settings override their categories, and per-file overrides apply before categories are expanded. Configurations without categories run only the type-aware rules they name. `--type-check` independently enables TypeScript compiler diagnostics.
