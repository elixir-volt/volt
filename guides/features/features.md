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

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour. Plugins can resolve imports, load custom file formats, transform code, and run JavaScript build tools through `Volt.JS.Runtime`.

See [Plugins](plugins.md) for the full hook API and examples.
