# Features

## JavaScript and TypeScript

Volt compiles JavaScript and TypeScript through [OXC](https://oxc.rs), a Rust-based toolchain. ES2020+ syntax is downleveled to your configured target. TypeScript types are stripped at compile time without type-checking — use `tsc --noEmit` separately if you want type safety.

## Vue and Svelte

Vue single-file components (`.vue`) compile through Vize with scoped CSS and optional Vapor mode. Svelte components (`.svelte`) compile through QuickBEAM. Both work without Node.js installed. Import `.vue` and `.svelte` files directly from your application code.

## React and JSX

JSX and TSX files are transformed by OXC. Set `import_source: "react"` in your Volt config to use React's automatic JSX runtime. Volt includes a React plugin that pre-bundles `react`, `react-dom/client`, and `react/jsx-runtime` into a single vendor module for efficient loading.

See [Frontend Frameworks](frameworks.md) for setup instructions and entry point examples for each framework.

## Tailwind CSS

Volt compiles Tailwind CSS v4 natively. [Oxide](https://hex.pm/packages/oxide_ex) scans source files in parallel for candidate class names, then the Tailwind compiler generates CSS. In dev mode, only changed files are re-scanned — editing a `.heex` template triggers an incremental CSS rebuild and hot-swaps the stylesheet without a page reload.

See [Tailwind CSS](tailwind.md) for configuration and the programmatic API.

## Hot Module Replacement

The dev server pushes updates over a WebSocket. CSS changes hot-swap without a page reload. JavaScript modules that call `import.meta.hot.accept()` are re-imported in place. Vue style-only changes skip the full recompile.

See [HMR](hmr.md) for the `import.meta.hot` API.

## Code Splitting

Dynamic `import()` calls automatically create separate async chunks. Shared modules between chunks are extracted to avoid duplication. Manual chunk boundaries can be configured for vendor splitting.

See [Code Splitting](code-splitting.md) for examples and configuration.

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

Images, fonts, and other files are handled automatically when imported:

```typescript
import logo from './logo.svg'  // small files → data URI
import photo from './photo.jpg' // large files → hashed URL
```

## JSON Imports

```typescript
import config from './config.json'
console.log(config.apiUrl)
```

## Environment Variables

Create `.env` files in your project root. Variables prefixed with `VOLT_` are available as `import.meta.env.VOLT_*` in client code. Built-in variables include `MODE`, `DEV`, and `PROD`.

See [Environment Variables](environment-variables.md) for file loading order and modes.

## Glob Imports

`import.meta.glob()` resolves glob patterns at build time:

```typescript
const pages = import.meta.glob('./pages/*.ts', { eager: true })
```

See [Glob Imports](glob-imports.md) for lazy vs eager loading.

## `Volt.entry_path/2`

Use `Volt.entry_path/2` in your root layout to link to the entry script:

```heex
<script defer phx-track-static type="module" src={Volt.entry_path(MyAppWeb.Endpoint)}></script>
```

In development, this returns the source path served by the dev server (e.g. `/assets/js/app.ts`). In production, it reads `manifest.json` and returns the content-hashed path (e.g. `/assets/js/app-5e6f7a8b.js`).

## Multi-Entry Builds

For multi-page apps, specify multiple entry points:

```elixir
config :volt, entry: ["assets/js/app.ts", "assets/js/admin.ts"]
```

Or via CLI: `mix volt.build --entry assets/js/app.ts --entry assets/js/admin.ts`

Each entry produces its own bundle and manifest entry. Use `Volt.entry_path/2` with the `:name` override to reference a specific entry:

```elixir
Volt.entry_path(MyAppWeb.Endpoint, name: "admin")
```

## HTML Entry Points

Entry files can be HTML — `<script src="...">` tags are extracted as JS entry points:

```bash
mix volt.build --entry index.html
```

## Import Aliases

Configure path aliases in Volt config:

```elixir
config :volt, aliases: %{"@" => "assets/src"}
```

```typescript
import { Button } from '@/components/Button'
```

Volt also reads `compilerOptions.paths` from `tsconfig.json` automatically.

## External Modules

Exclude packages the host page already provides:

```elixir
config :volt, external: ~w(phoenix phoenix_html phoenix_live_view)
```

## Source Maps

Production builds write `.map` files by default. Use `sourcemap: :hidden` to write maps without the URL comment (for Sentry, Datadog, etc.), or `sourcemap: false` to skip.

## Formatting and Linting

Volt includes Prettier-compatible JS/TS formatting via oxfmt (~30× faster) and 650+ oxlint rules, both as Rust NIFs. `Volt.Formatter` integrates with `mix format`. Custom lint rules can be written in Elixir.

See [Formatting and Linting](formatting-and-linting.md) for setup and configuration.

## Web Workers

Worker URLs using the standard pattern are rewritten in production builds:

```typescript
const worker = new Worker(new URL('./worker.ts', import.meta.url))
```

The worker file is built as a separate entry and the URL is rewritten to the hashed output path.

## Dev Console Forwarding

In development, browser `console.log`, `console.warn`, and `console.error` calls are forwarded to the Elixir terminal, so you can see client-side logs alongside server logs without opening browser DevTools.

## Error Overlay

Compilation errors in development are displayed as a full-screen browser overlay with the error message. The overlay dismisses on click and clears automatically when the error is fixed.

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour. Plugins can resolve imports, load custom file formats, transform code, and run JavaScript build tools through `Volt.JS.Runtime`.

See [Plugins](plugins.md) for the full hook API and examples.
