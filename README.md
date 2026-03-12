# Volt ⚡

Elixir-native frontend build tool. Dev server with HMR, Tailwind CSS compilation, and production bundling — no Node.js, no esbuild, no Vite.

Built on Rust NIFs: [OXC](https://hex.pm/packages/oxc) for JS/TS, [Vize](https://hex.pm/packages/vize) for Vue SFCs + LightningCSS, [Oxide](https://hex.pm/packages/oxide_ex) for Tailwind scanning, and [QuickBEAM](https://hex.pm/packages/quickbeam) for the Tailwind compiler.

## Features

- **Zero JavaScript toolchain** — no `node_modules`, no npm, no npx
- **JS/TS bundling** — parse, transform, minify via OXC (Rust)
- **Vue SFC support** — single-file components with scoped CSS and Vapor IR
- **Tailwind CSS v4** — parallel content scanning + full compiler, ~40ms builds
- **Dev server** — on-demand compilation with mtime caching and error overlays
- **HMR** — file watcher, WebSocket push, CSS hot-swap without page reload
- **Production builds** — tree-shaken bundles with content-hashed filenames and manifests

## Installation

```elixir
def deps do
  [{:volt, "~> 0.1.0"}]
end
```

## Quick Start

### Dev Server

Add the Plug to your Phoenix endpoint:

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  plug Volt.DevServer,
    root: "assets",
    prefix: "/assets",
    target: "es2020"
end
```

Start the watcher in `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    volt: {Mix.Tasks.Volt.Dev, :run,
      [~w(--tailwind --tailwind-css assets/css/app.css --watch-dir lib/)]}
  ]
```

### Production Build

```bash
mix volt.build \
  --entry assets/js/app.ts \
  --outdir priv/static/assets \
  --resolve-dir deps \
  --tailwind --tailwind-css assets/css/app.css
```

```
Building Tailwind CSS...
  app.css  23.9 KB
Built Tailwind in 43ms
Building assets/js/app.ts...
  app.js  128.4 KB
  manifest.json  1 entries
Built in 15ms
```

## Tailwind CSS

Volt compiles Tailwind CSS natively — no CLI binary, no CDN.

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

Custom CSS works — `@import "tailwindcss"` is inlined automatically:

```css
@import "tailwindcss" source(none);

@custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
[data-phx-session] { display: contents }
```

### Incremental Rebuilds

In dev mode, only changed files are re-scanned. If a `.heex` template adds new Tailwind classes, only those new candidates trigger a CSS rebuild — the browser gets a style-only update without a page reload.

## HMR

The file watcher monitors your asset and template directories:

| File type | Action |
|-----------|--------|
| `.ts`, `.tsx`, `.js`, `.jsx`, `.vue`, `.css` | Recompile via Pipeline, push update over WebSocket |
| `.ex`, `.heex`, `.eex` | Incremental Tailwind rebuild, CSS hot-swap |
| `.vue` (style-only change) | CSS hot-swap, no page reload |

The browser client auto-reconnects on disconnect and shows compilation errors as an overlay.

## Mix Tasks

### `mix volt.build`

Build production assets.

```
--entry          Entry file (default: assets/js/app.ts)
--outdir         Output directory (default: priv/static/assets)
--target         JS target (default: es2020)
--resolve-dir    Additional resolution directory (repeatable, e.g. deps)
--no-minify      Skip minification
--no-sourcemap   Skip source maps
--no-hash        Stable filenames (for dev builds)
--tailwind       Build Tailwind CSS
--tailwind-css   Custom Tailwind input CSS file
--tailwind-source  Source directory for scanning (repeatable)
```

### `mix volt.dev`

Start the file watcher for development.

```
--root           Asset source directory (default: assets)
--watch-dir      Additional directory to watch (repeatable)
--tailwind       Enable Tailwind CSS rebuilds
--tailwind-css   Custom Tailwind input CSS file
--target         JS target (default: es2020)
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
result.hashes  #=> %{template: "abc...", style: "def...", script: "ghi..."}

# CSS
{:ok, result} = Volt.Pipeline.compile("styles.css", source, minify: true)
```

## Stack

```
volt
├── oxc       — JS/TS parse, transform, bundle, minify (Rust NIF)
├── vize      — Vue SFC compilation, Vapor IR, LightningCSS (Rust NIF)
├── oxide_ex  — Tailwind content scanning, candidate extraction (Rust NIF)
├── quickbeam — Tailwind compiler runtime (QuickJS on BEAM)
└── plug      — HTTP dev server
```

## Demo

See [`examples/demo/`](examples/demo/) for a full Phoenix app using Volt + [PhoenixVapor](https://github.com/dannote/phoenix_vapor) — Vue templates rendered as native LiveView, Tailwind CSS, no JavaScript runtime for SSR.

## License

MIT © 2026 Danila Poyarkov
