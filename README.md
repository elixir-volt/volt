# Volt ⚡

Elixir-native frontend build tool. Dev server with HMR, Tailwind CSS compilation, and production bundling — no Node.js, no esbuild, no Vite.

Built on Rust NIFs: [OXC](https://hex.pm/packages/oxc) for JS/TS, [Vize](https://hex.pm/packages/vize) for Vue SFCs + LightningCSS, [Oxide](https://hex.pm/packages/oxide_ex) for Tailwind scanning, and [QuickBEAM](https://hex.pm/packages/quickbeam) for the Tailwind compiler.

## Features

- **No JavaScript app bundler** — Volt builds app assets natively without esbuild or Vite
- **JS/TS bundling** — parse, transform, minify via OXC (Rust)
- **Vue SFC support** — single-file components with scoped CSS and Vapor IR
- **Tailwind CSS v4** — parallel content scanning + full compiler, ~40ms builds
- **Dev server** — on-demand compilation with mtime caching and error overlays
- **HMR** — file watcher, WebSocket push, CSS hot-swap without page reload
- **Production builds** — tree-shaken bundles with content-hashed filenames and manifests
- **Code splitting** — dynamic `import()` creates async chunks, shared code extracted automatically
- **CSS Modules** — `.module.css` with LightningCSS-powered scoping
- **Static assets** — images, fonts, SVGs inlined or hashed
- **JSON imports** — `import data from './data.json'`
- **Environment variables** — `.env` files with `import.meta.env.VOLT_*`
- **Import aliases** — `@/components/Button` → `assets/src/components/Button`
- **tsconfig.json paths** — reads `compilerOptions.paths` automatically, no config duplication
- **Source maps** — production `.map` files with optional hidden mode for error tracking
- **Manual chunks** — control chunk boundaries (e.g. vendor splitting) via config
- **`import.meta.hot`** — per-module HMR with `accept()`, `dispose()`, and preserved state
- **Plugin system** — resolve, load, transform, and render_chunk hooks
- **External modules** — exclude packages from the bundle (e.g. Phoenix JS deps)
- **JS/TS formatting** — Prettier-compatible oxfmt via NIF, ~30× faster than Prettier
- **JS/TS linting** — 650+ oxlint rules via NIF, plus custom Elixir rules

## Installation

```bash
mix igniter.install volt
```

This will add the dep, configure Volt in `config.exs` and `dev.exs`,
add the dev server plug to your endpoint, and remove esbuild/tailwind.

Or add manually:

```elixir
def deps do
  [{:volt, "~> 0.8.1"}]
end
```

## Configuration

All config lives in your standard `config/*.exs` files:

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  root: "assets",
  sources: ["**/*.{js,ts,jsx,tsx,vue}"],
  ignore: ["node_modules/**", "vendor/**"],
  target: :es2020,
  sourcemap: :hidden,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  aliases: %{
    "@" => "assets/src",
    "@components" => "assets/src/components"
  },
  chunks: %{
    "vendor" => ["vue", "vue-router"]
  },
  format: :iife,
  plugins: [],
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{vue,ts,tsx}"}
    ]
  ]

# config/dev.exs
config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/"]
```

CLI flags override config values for one-off use.

## Quick Start

```bash
mix igniter.install volt
mix phx.server
```

The installer configures everything: build settings, dev server plug, watcher, format and lint config.

For manual setup or details, see the sections below.

### Production Build

```bash
mix volt.build
```

```
Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB
  manifest.json  2 entries
Built in 15ms
```

## Code Splitting

Dynamic imports are automatically split into separate chunks:

```typescript
// Loaded immediately
import { setup } from "./core";

// Loaded on demand — becomes a separate chunk
const admin = await import("./admin");
```

Produces:

```
app-5e6f7a8b.js        42 KB   (entry)
app-admin-c3d4e5f6.js  86 KB   (async)
manifest.json           3 entries
```

Shared modules between chunks are extracted into common chunks to avoid duplication.

Disable with `code_splitting: false` in config or `--no-code-splitting` flag.

### Manual Chunks

Control chunk boundaries explicitly:

```elixir
config :volt,
  chunks: %{
    "vendor" => ["vue", "vue-router", "pinia"],
    "ui" => ["assets/src/components"]
  }
```

Bare specifiers match package names in `node_modules`. Path patterns match by directory prefix. Manual chunks work alongside automatic dynamic-import splitting.

## Source Maps

Production builds write `.map` files by default:

- `sourcemap: true` — write `.map` files and append `//# sourceMappingURL` comment (default)
- `sourcemap: :hidden` — write `.map` files without the URL comment (for Sentry, Datadog, etc.)
- `sourcemap: false` — no source maps

CLI: `--sourcemap hidden` or `--no-sourcemap`.

## External Modules

Exclude packages that the host page already provides:

```elixir
config :volt, external: ~w(phoenix phoenix_html phoenix_live_view)
```

Or per-build: `mix volt.build --external phoenix --external phoenix_html`

## CSS Modules

Files ending in `.module.css` get scoped class names via LightningCSS:

```css
/* button.module.css */
.primary {
  color: blue;
}
```

```typescript
import styles from "./button.module.css";
console.log(styles.primary); // "ewq3O_primary"
```

## Static Assets

Images, fonts, and other files are handled automatically:

```typescript
import logo from "./logo.svg"; // small → data:image/svg+xml;base64,...
import photo from "./photo.jpg"; // large → /assets/photo-a1b2c3d4.jpg
```

## JSON Imports

```typescript
import config from "./config.json";
console.log(config.apiUrl);
```

## Environment Variables

Create `.env` files in your project root:

```
VOLT_API_URL=https://api.example.com
VOLT_DEBUG=true
```

Access in your code:

```typescript
console.log(import.meta.env.VOLT_API_URL);
console.log(import.meta.env.MODE); // "development" or "production"
console.log(import.meta.env.DEV); // true/false
console.log(import.meta.env.PROD); // true/false
```

Files loaded: `.env`, `.env.local`, `.env.{mode}`, `.env.{mode}.local`

## Import Aliases

```elixir
config :volt, aliases: %{"@" => "assets/src"}
```

```typescript
import { Button } from "@/components/Button";
// resolves to assets/src/components/Button
```

### tsconfig.json Paths

Volt automatically reads `compilerOptions.paths` from `tsconfig.json` in the project root:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "phoenix": ["../deps/phoenix"]
    }
  }
}
```

These are merged into aliases — explicit `aliases` in Volt config take precedence. No need to duplicate path mappings.

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour:

```elixir
defmodule MyApp.MarkdownPlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "markdown"

  @impl true
  def resolve(spec, _importer) do
    if String.ends_with?(spec, ".md"), do: {:ok, spec}
  end

  @impl true
  def load(path) do
    if String.ends_with?(path, ".md") do
      html = path |> File.read!() |> Earmark.as_html!()
      {:ok, "export default #{Jason.encode!(html)};\n"}
    end
  end

  def resolve(_, _), do: nil
  def load(_), do: nil
end
```

```elixir
config :volt, plugins: [MyApp.MarkdownPlugin]
```

Hooks: `resolve/2`, `load/1`, `transform/2`, `render_chunk/2` — all optional.

## Tailwind CSS

Volt compiles Tailwind CSS natively at runtime and installs the Tailwind compiler into the npm_ex cache on first use.

[Oxide](https://hex.pm/packages/oxide_ex) scans your source files in parallel for candidate class names, then the Tailwind v4 compiler (running in [QuickBEAM](https://hex.pm/packages/quickbeam)) generates the CSS. [LightningCSS](https://hex.pm/packages/vize) handles minification.

```elixir
# Programmatic API
{:ok, css} = Volt.Tailwind.build(
  sources: [
    %{base: "lib/", pattern: "**/*.{ex,heex}"},
    %{base: "assets/", pattern: "**/*.{vue,ts,tsx}"}
  ],
  css: File.read!("assets/css/app.css"),
  minify: true
)
```

### Incremental Rebuilds

In dev mode, only changed files are re-scanned. If a `.heex` template adds new Tailwind classes, only those new candidates trigger a CSS rebuild — the browser gets a style-only update without a page reload.

## HMR

The file watcher monitors your asset and template directories:

| File type                                    | Action                                             |
| -------------------------------------------- | -------------------------------------------------- |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.vue`, `.css` | Recompile via Pipeline, push update over WebSocket |
| `.ex`, `.heex`, `.eex`                       | Incremental Tailwind rebuild, CSS hot-swap         |
| `.vue` (style-only change)                   | CSS hot-swap, no page reload                       |

The browser client auto-reconnects on disconnect and shows compilation errors as an overlay.

### `import.meta.hot`

Each module served in dev mode includes an `import.meta.hot` object for granular HMR:

```typescript
// clock.ts
let timer: ReturnType<typeof setInterval>;

export function startClock(el: HTMLElement) {
  const update = () => { el.textContent = new Date().toLocaleTimeString(); };
  update();
  timer = setInterval(update, 1000);
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => clearInterval(timer));
  import.meta.hot.accept();
}
```

When a file changes, Volt walks the dependency graph upward to find the nearest module with `import.meta.hot.accept()`. Only that module is re-imported — no full page reload. If no boundary is found, falls back to `location.reload()`.

API: `accept()`, `accept(deps, cb)`, `dispose(cb)`, `data`, `invalidate()`.

## Mix Tasks


### `mix igniter.install volt`

Set up Volt in a Phoenix project. Adds config, dev server plug, watcher,
removes esbuild/tailwind deps.

### `mix format` integration

`Volt.Formatter` is a `mix format` plugin — add it to `.formatter.exs` and JS/TS files are formatted alongside Elixir:

```elixir
# .formatter.exs
[
  plugins: [Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "assets/**/*.{js,ts,jsx,tsx}"
  ]
]
```

Reads options from `config :volt, :format` or `.oxfmtrc.json` (see below).

### `mix volt.js.format`

Format JavaScript and TypeScript assets using oxfmt via NIF — no Node.js required.

```
mix volt.js.format
```

### `mix volt.js.check`

Check formatting and lint in one command. Exits with non-zero status on issues.

```
mix volt.js.check
```

### Formatter & linter configuration

```elixir
# config/config.exs
config :volt, :format,
  print_width: 100,
  semi: false,
  single_quote: true,
  trailing_comma: :none,
  arrow_parens: :always

config :volt, :lint,
  plugins: [:typescript],
  rules: %{
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-explicit-any" => :warn
  }
```

All [oxfmt options](https://hexdocs.pm/oxc/OXC.Format.html) are supported. Falls back to `.oxfmtrc.json` if no Elixir config is set.

File discovery for all JS tasks uses `sources:` and `ignore:` from `config :volt` (see Configuration above).

### `mix volt.lint`

Lint JavaScript and TypeScript assets using oxlint via NIF — no Node.js required.

```
mix volt.lint
mix volt.lint --plugin react --plugin typescript
```

Available plugins: `react`, `typescript`, `unicorn`, `import`, `jsdoc`, `jest`, `vitest`, `jsx_a11y`, `nextjs`, `react_perf`, `promise`, `node`, `vue`, `oxc`.

Custom lint rules can be written in Elixir using the `OXC.Lint.Rule` behaviour — see the [oxc docs](https://hexdocs.pm/oxc/OXC.Lint.Rule.html).

### `mix volt.build`

Build production assets. Reads from `config :volt`, CLI flags override.

```
--entry          Entry file (repeatable for multi-page apps)
--outdir         Output directory
--target         JS target (e.g. es2020)
--external       Exclude from bundle (repeatable)
--no-minify      Skip minification
--no-sourcemap   Skip source maps
--no-hash        Stable filenames
--no-code-splitting  Disable chunk splitting
--mode           Build mode for env variables
--format         Output format: iife, esm, or cjs
--resolve-dir    Additional resolution directory (repeatable)
--tailwind       Build Tailwind CSS
--tailwind-css   Custom Tailwind input CSS file
--tailwind-source  Source directory for scanning (repeatable)
```

### `mix volt.dev`

Start the file watcher for development.

```
--root           Asset source directory
--watch-dir      Additional directory to watch (repeatable)
--tailwind       Enable Tailwind CSS rebuilds
--tailwind-css   Custom Tailwind input CSS file
--target         JS target
```

## Pipeline

`Volt.Pipeline` compiles individual files:

```elixir
# TypeScript
{:ok, result} = Volt.Pipeline.compile("app.ts", source)
result.code       #=> "const x = 42;\n"
result.sourcemap  #=> "{\"version\":3, ...}"

# Vue SFC
{:ok, result} = Volt.Pipeline.compile("App.vue", source)
result.code    #=> compiled JavaScript
result.css     #=> scoped CSS (or nil)

# CSS Modules
{:ok, result} = Volt.Pipeline.compile("btn.module.css", source)
result.code    #=> export default {"btn":"ewq3O_btn"}
result.css     #=> .ewq3O_btn { color: red }

# JSON
{:ok, result} = Volt.Pipeline.compile("data.json", source)
result.code    #=> export default {"key":"value"}
```

## Stack

```
volt
├── oxc       — JS/TS parse, transform, bundle, minify, lint (Rust NIF)
├── vize      — Vue SFC compilation, CSS Modules, LightningCSS (Rust NIF)
├── oxide_ex  — Tailwind content scanning, candidate extraction (Rust NIF)
├── quickbeam — Tailwind compiler runtime (QuickJS on BEAM)
└── plug      — HTTP dev server
```

## Plugins

Volt core handles JavaScript/TypeScript, CSS, JSON, assets, bundling, the dev server, and HMR. Vue support is included out of the box, so `.vue` files can be imported directly from your app.

Additional file formats can be enabled by adding plugins to your Volt config. For example, once Svelte support is available, setup should look like:

```elixir
config :volt,
  plugins: [VoltSvelte]
```

After that, `.svelte` files should work like any other import.

## Demo

See the [demo app](https://github.com/elixir-volt/volt/tree/master/examples/demo) for a full Phoenix app using Volt + [PhoenixVapor](https://github.com/dannote/phoenix_vapor) — Vue templates rendered as native LiveView, Tailwind CSS, no JavaScript runtime for SSR.

## License

MIT © 2026 Danila Poyarkov
