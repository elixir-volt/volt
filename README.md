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
- **Code splitting** — dynamic `import()` creates async chunks, shared code extracted automatically
- **CSS Modules** — `.module.css` with LightningCSS-powered scoping
- **Static assets** — images, fonts, SVGs inlined or hashed
- **JSON imports** — `import data from './data.json'`
- **Environment variables** — `.env` files with `import.meta.env.VOLT_*`
- **Import aliases** — `@/components/Button` → `assets/src/components/Button`
- **Plugin system** — resolve, load, transform, and render_chunk hooks
- **External modules** — exclude packages from the bundle (e.g. Phoenix JS deps)

## Installation

```elixir
def deps do
  [{:volt, "~> 0.2.0"}]
end
```

## Configuration

All config lives in your standard `config/*.exs` files:

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  target: :es2020,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  aliases: %{
    "@" => "assets/src",
    "@components" => "assets/src/components"
  },
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

### Dev Server

Add the Plug to your Phoenix endpoint:

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  plug Volt.DevServer, root: "assets"
end
```

Start the watcher in `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    volt: {Mix.Tasks.Volt.Dev, :run, [~w(--tailwind)]}
  ]
```

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
import { setup } from './core'

// Loaded on demand — becomes a separate chunk
const admin = await import('./admin')
```

Produces:

```
app-5e6f7a8b.js        42 KB   (entry)
app-admin-c3d4e5f6.js  86 KB   (async)
manifest.json           3 entries
```

Shared modules between chunks are extracted into common chunks to avoid duplication.

Disable with `code_splitting: false` in config or `--no-code-splitting` flag.

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
.primary { color: blue }
```

```typescript
import styles from './button.module.css'
console.log(styles.primary) // "ewq3O_primary"
```

## Static Assets

Images, fonts, and other files are handled automatically:

```typescript
import logo from './logo.svg'    // small → data:image/svg+xml;base64,...
import photo from './photo.jpg'  // large → /assets/photo-a1b2c3d4.jpg
```

## JSON Imports

```typescript
import config from './config.json'
console.log(config.apiUrl)
```

## Environment Variables

Create `.env` files in your project root:

```
VOLT_API_URL=https://api.example.com
VOLT_DEBUG=true
```

Access in your code:

```typescript
console.log(import.meta.env.VOLT_API_URL)
console.log(import.meta.env.MODE)  // "development" or "production"
console.log(import.meta.env.DEV)   // true/false
console.log(import.meta.env.PROD)  // true/false
```

Files loaded: `.env`, `.env.local`, `.env.{mode}`, `.env.{mode}.local`

## Import Aliases

```elixir
config :volt, aliases: %{"@" => "assets/src"}
```

```typescript
import { Button } from '@/components/Button'
// resolves to assets/src/components/Button
```

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
├── oxc       — JS/TS parse, transform, bundle, minify (Rust NIF)
├── vize      — Vue SFC compilation, CSS Modules, LightningCSS (Rust NIF)
├── oxide_ex  — Tailwind content scanning, candidate extraction (Rust NIF)
├── quickbeam — Tailwind compiler runtime (QuickJS on BEAM)
└── plug      — HTTP dev server
```

## Demo

See [`examples/demo/`](examples/demo/) for a full Phoenix app using Volt + [PhoenixVapor](https://github.com/dannote/phoenix_vapor) — Vue templates rendered as native LiveView, Tailwind CSS, no JavaScript runtime for SSR.

## License

MIT © 2026 Danila Poyarkov
