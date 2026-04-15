# Volt Demo

A Phoenix LiveView app using **Volt** as the asset pipeline and **PhoenixVapor** for Vue template rendering — no esbuild, no Node.js, no JavaScript runtime for SSR.

## What this demonstrates

- `~VUE` sigil compiles Vue templates to native `%Phoenix.LiveView.Rendered{}` structs
- `mix volt.build` bundles TypeScript with content hashing and source maps
- **tsconfig.json paths** — Volt reads `compilerOptions.paths` automatically, no need to duplicate aliases in Volt config
- **Hidden source maps** — `sourcemap: :hidden` writes `.map` files without `sourceMappingURL` comment (for error tracking services like Sentry)
- **HMR with `import.meta.hot`** — the clock widget (`clock.ts`) self-accepts updates: edit it and see changes without full reload
- **Alias imports** — `import { startClock } from "@/clock"` resolves via tsconfig paths
- Volt resolves Phoenix deps directly from `deps/` via `resolve_dirs`

## Setup

```sh
mix setup
```

## Run

```sh
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) — counter with Vue template syntax, backed by LiveView.

## Pages

- `/` — Counter (increment, decrement, reset)
- `/todo` — Todo list (add, toggle, delete, filter)

## HMR demo

While `mix phx.server` is running, edit `assets/js/clock.ts` — the clock in the top-right corner updates without a full page reload, preserving LiveView state.
