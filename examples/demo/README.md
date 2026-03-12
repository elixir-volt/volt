# Volt Demo

A Phoenix LiveView app using **Volt** as the asset pipeline and **LiveVueNext** for Vue template rendering — no esbuild, no Node.js, no JavaScript runtime for SSR.

## What this demonstrates

- `~VUE` sigil compiles Vue templates to native `%Phoenix.LiveView.Rendered{}` structs
- `mix volt.build` bundles TypeScript (Phoenix + LiveView JS client) with content hashing
- Volt resolves Phoenix deps (`phoenix`, `phoenix_live_view`, `phoenix_html`) directly from `deps/`
- Vue directives (`v-if`, `v-for`, `:class`, `phx-click`) work natively with LiveView

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
