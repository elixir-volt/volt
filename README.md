# Volt ⚡

Elixir-native frontend build tool. Dev server with HMR, Tailwind CSS compilation, and production bundling — no Node.js, no esbuild, no Vite.

Built on Rust NIFs: [OXC](https://hex.pm/packages/oxc) for JS/TS, [Vize](https://hex.pm/packages/vize) for Vue SFCs + LightningCSS, [Oxide](https://hex.pm/packages/oxide_ex) for Tailwind scanning, and [QuickBEAM](https://hex.pm/packages/quickbeam) for JavaScript tool runtimes like Tailwind and Svelte.

## Features

- **No JavaScript app bundler** — Volt builds app assets natively without esbuild or Vite
- **JS/TS bundling** — parse, transform, minify via OXC (Rust)
- **Vue SFC support** — single-file components with scoped CSS and Vapor IR
- **Svelte support** — `.svelte` components compiled through QuickBEAM without Node.js
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

## Stack

```
volt
├── oxc       — JS/TS parse, transform, bundle, minify, lint (Rust NIF)
├── vize      — Vue SFC compilation, CSS Modules, LightningCSS (Rust NIF)
├── oxide_ex  — Tailwind content scanning, candidate extraction (Rust NIF)
├── quickbeam — JavaScript tool runtime (QuickJS on BEAM)
└── plug      — HTTP dev server
```

## Installation

```bash
mix igniter.install volt
```

This will add the dep, configure Volt in `config.exs` and `dev.exs`,
add the dev server plug to your endpoint, and remove esbuild/tailwind.

Or add manually:

```elixir
def deps do
  [{:volt, "~> 0.9.2"}]
end
```

## Quick Start

```bash
mix igniter.install volt
mix phx.server
```

The installer configures everything: build settings, dev server plug, watcher, format and lint config.

See the [Getting Started guide](guides/introduction/getting-started.md) for manual setup.

## Examples

See the example apps for Phoenix projects using Volt with [Vue](https://github.com/elixir-volt/volt/tree/master/examples/vue), [Svelte](https://github.com/elixir-volt/volt/tree/master/examples/svelte), and [React](https://github.com/elixir-volt/volt/tree/master/examples/react). Each example demonstrates JSON imports, SVG assets, CSS Modules, glob imports, environment variables, HMR, and Tailwind CSS.

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/volt).

## License

MIT © 2026 Danila Poyarkov
