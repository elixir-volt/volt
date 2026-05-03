# Frontend Frameworks

Volt has built-in support for Vue, Svelte, and React. No Node.js runtime is required — each framework's compiler runs through Rust NIFs or QuickBEAM.

## React

React JSX and TSX files are transformed natively by OXC using the automatic JSX runtime.

### Setup

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.tsx",
  sources: ["**/*.{js,ts,jsx,tsx}"],
  import_source: "react"

config :volt, :lint, plugins: [:typescript, :react]
```

```json
// package.json
{
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  }
}
```

### Entry Point

```tsx
import { createRoot } from 'react-dom/client'
import App from './App'

const root = createRoot(document.getElementById('app')!)
root.render(<App />)

if (import.meta.hot) {
  import.meta.hot.accept()
}
```

Volt pre-bundles `react`, `react-dom/client`, and `react/jsx-runtime` into a single vendor module automatically.

## Vue

Vue single-file components (`.vue`) compile through [Vize](https://hex.pm/packages/vize), a Rust NIF wrapping the official Vue compiler. Scoped CSS, `<script setup>`, and TypeScript in SFCs are all supported.

### Setup

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  sources: ["**/*.{js,ts,jsx,tsx,vue}"],
  tailwind: [
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx,vue}"}
    ]
  ]

config :volt, :lint, plugins: [:typescript, :vue]
```

```json
// package.json
{
  "dependencies": {
    "vue": "^3.5.0"
  }
}
```

### Entry Point

```javascript
import { createApp } from 'vue'
import App from './App.vue'

const app = createApp(App)
app.mount('#app')

if (import.meta.hot) {
  import.meta.hot.dispose(() => app.unmount())
  import.meta.hot.accept()
}
```

### Vapor Mode

Vue Vapor mode generates more efficient compiled output. Enable it in config:

```elixir
config :volt, vapor: true
```

## Svelte

Svelte components (`.svelte`) compile through [QuickBEAM](https://hex.pm/packages/quickbeam), which runs the Svelte compiler in-process without Node.js. Svelte 5 runes (`$state`, `$derived`, `$props`) are supported.

### Setup

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  sources: ["**/*.{js,ts,jsx,tsx,svelte}"],
  tailwind: [
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx,svelte}"}
    ]
  ]

config :volt, :lint, plugins: [:typescript]
```

```json
// package.json
{
  "dependencies": {
    "svelte": "^5.0.0"
  }
}
```

### Entry Point

```javascript
import { mount, unmount } from 'svelte'
import App from './App.svelte'

const target = document.getElementById('app')!
const app = mount(App, { target })

if (import.meta.hot) {
  import.meta.hot.dispose(() => unmount(app))
  import.meta.hot.accept()
}
```

## Vanilla TypeScript

Volt works without any frontend framework. Use plain TypeScript with Phoenix LiveView hooks for interactivity — the same setup Phoenix uses by default, with Volt replacing esbuild.

See the [vanilla example](https://github.com/elixir-volt/volt/tree/master/examples/vanilla) for a complete project with LiveView hooks, JSON imports, glob imports, and `import.meta.env`.

## Examples

See the [example apps](https://github.com/elixir-volt/volt/tree/master/examples) for complete Phoenix projects using each framework.
