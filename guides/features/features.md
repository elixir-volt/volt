# Features

## Elixir-Native Toolchain

Volt keeps the frontend toolchain inside the BEAM. The dev server, production builds, Tailwind rebuilds, formatting, linting, and plugin hooks run from Mix tasks and Elixir configuration instead of a separate Node.js watcher.

Runtime npm package installs use `npm_ex`, which ignores package lifecycle hooks by default. Packages installed for embedded JS runtimes do not execute `preinstall`, `install`, or `postinstall` scripts.

## JavaScript and TypeScript

Volt compiles JavaScript and TypeScript through [OXC](https://oxc.rs), a Rust-based toolchain. ES2020+ syntax is downleveled to your configured target. TypeScript types are stripped at compile time without type-checking — use `tsc --noEmit` separately if you want type safety.

## Vue and Svelte

Vue single-file components (`.vue`) compile through Vize with scoped CSS and optional Vapor mode. Svelte components (`.svelte`) compile through QuickBEAM. Both work without Node.js installed. Import `.vue` and `.svelte` files directly from your application code.

## React, Solid, and JSX

JSX and TSX files are transformed by OXC. Set `import_source: "react"` in your Volt config to use React's automatic JSX runtime. Volt includes a React plugin that pre-bundles `react`, `react-dom/client`, and `react/jsx-runtime` into a single vendor module for efficient loading.

Solid JSX/TSX is supported through `Volt.Plugin.Solid`, which compiles Solid components through QuickBEAM without requiring Node.js in the host application.

See [Frontend Frameworks](frameworks.md) for setup instructions and entry point examples for each framework.

## Tailwind CSS

Volt compiles Tailwind CSS v4 natively. [Oxide](https://hex.pm/packages/oxide_ex) scans source files in parallel for candidate class names, then the Tailwind compiler generates CSS. In dev mode, only changed files are re-scanned — editing a `.heex` template triggers an incremental CSS rebuild and hot-swaps the stylesheet without a page reload.

Tailwind `@plugin` and `@config` directives are resolved and bundled automatically, including local files and npm packages.

See [Tailwind CSS](tailwind.md) for configuration and the programmatic API.

## Hot Module Replacement

The dev server pushes updates over a WebSocket. CSS changes hot-swap without a page reload. JavaScript modules that call `import.meta.hot.accept()` are re-imported in place. Vue style-only changes skip the full recompile.

See [HMR](hmr.md) for the `import.meta.hot` API.

## Production Builds

Production builds include tree-shaking, minification, code splitting, asset URL rewriting, content-hashed JavaScript/CSS/assets, source maps, and a `manifest.json` ready for `mix phx.digest`.

## Code Splitting

Dynamic `import()` calls automatically create separate async chunks. Simple relative dynamic import variables such as ``import(`./pages/${name}.ts`)`` are expanded through `import.meta.glob()` so production builds can include matching modules. Shared modules between chunks are extracted to avoid duplication. Chunk-local CSS and assets are recorded in the production manifest.

`Volt.Preload` can generate `<link rel="modulepreload">` tags from the production manifest for entry/static imports. Runtime dynamic imports preload their own dependency chunks and CSS when needed.

See [Code Splitting](code-splitting.md) for examples and configuration.

## Sass and SCSS

Volt compiles `.scss` and indented `.sass` files through the native Rust `grass` compiler before passing the resulting CSS to LightningCSS. Variables, nesting, mixins, partials, `@use`, and relative imports work without installing Sass or Node.js:

```scss
/* styles.scss */
$brand: #663399;

.button {
  color: $brand;

  &:hover {
    opacity: 0.8;
  }
}
```

```javascript
import './styles.scss'
```

Sass files participate in development watching, CSS hot replacement, production bundling, minification, and asset URL rewriting like ordinary CSS.

## CSS Modules

Files ending in `.module.css`, `.module.scss`, or `.module.sass` get scoped class names via LightningCSS after Sass preprocessing:

```css
/* button.module.css */
.primary { color: blue }
```

```javascript
import styles from './button.module.css'
console.log(styles.primary) // "ewq3O_primary"
```

## Static Assets

Images, fonts, and other files are handled automatically when imported from JavaScript or used with `new URL(..., import.meta.url)`:

```javascript
import logo from './logo.svg'      // small files → data URI
import photo from './photo.jpg?url' // forced hashed URL
import text from './message.txt?raw'
```

## JSON Imports

```javascript
import config from './config.json'
console.log(config.apiUrl)
```

## Environment Variables

Create `.env` files in your project root. Variables prefixed with `VOLT_` are available as `import.meta.env.VOLT_*` in client code by default. Use `env_prefix` to expose a different prefix such as `VITE_`. Built-in variables include `MODE`, `DEV`, and `PROD`.

See [Environment Variables](environment-variables.md) for file loading order and modes.

## Glob Imports

`import.meta.glob()` resolves glob patterns at build time:

```javascript
const pages = import.meta.glob('./pages/*.ts', { eager: true })
```

See [Glob Imports](glob-imports.md) for lazy vs eager loading, array and negative patterns, named imports, query options, and dynamic import variables.

## `Volt.static_path/2`

Use `Volt.static_path/2` in your root layout to link to Volt-managed scripts and stylesheets:

```heex
<link phx-track-static rel="stylesheet" href={Volt.static_path(MyAppWeb.Endpoint, "/assets/css/app.css")} />
<script defer phx-track-static type="module" src={Volt.static_path(MyAppWeb.Endpoint, "/assets/js/app.js")}></script>
<img src={Volt.static_path(MyAppWeb.Endpoint, "/assets/images/logo.svg")} />
```

In development, JavaScript entries return the source path served by the dev server (e.g. `/assets/js/app.ts`) and other paths are returned unchanged. In production, Volt reads `manifest.json` to find the content-hashed script, stylesheet, or emitted asset and then passes that path through the Phoenix endpoint's `static_path/1`. After `phx.digest`, the returned URL uses Phoenix's final digest and `?vsn=d`; without a Phoenix cache manifest it remains the Volt-hashed path. See [Production Builds](../deployment/production-builds.md#volt-hashes-and-phoenix-digests).

## Multi-Entry Builds

For multi-page apps, specify multiple entry points:

```elixir
config :volt, entry: ["assets/js/app.ts", "assets/js/admin.ts"]
```

Or via CLI: `mix volt.build --entry assets/js/app.ts --entry assets/js/admin.ts`

Each entry produces its own bundle and manifest entry. Reference the compiled asset path with `Volt.static_path/2`:

```elixir
Volt.static_path(MyAppWeb.Endpoint, "/assets/js/admin.js")
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

```javascript
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

Volt includes Prettier-compatible JS/TS formatting via oxfmt (~30× faster) and 650+ oxlint rules, both as Rust NIFs. `Volt.Formatter` integrates with `mix format` and can read Elixir config, `.oxfmtrc.json`, or `.prettierrc.json`.

Custom lint rules can be written in Elixir with `OXC.Lint.Rule` and configured alongside oxlint's built-in rules.

See [Formatting and Linting](formatting-and-linting.md) for setup and configuration.

## JavaScript and TypeScript Testing

Volt can register JS/TS test files as ordinary ExUnit tests. Tests import a Vitest-like API from `volt:test`, run in QuickBEAM, and report through the normal `mix test` pipeline.

See [JavaScript and TypeScript Testing](testing.md) for setup and API examples.

## Web Workers

Worker URLs using the standard pattern are rewritten in production builds:

```javascript
const worker = new Worker(new URL('./worker.ts', import.meta.url))
```

The worker file is built as a separate entry and the URL is rewritten to the hashed output path.

## Dev Console Forwarding

In development, browser `console.log`, `console.warn`, and `console.error` calls are forwarded to the Elixir terminal, so you can see client-side logs alongside server logs without opening browser DevTools.

## Error Overlay

Compilation errors in development are displayed as a full-screen browser overlay with the error message. The overlay dismisses on click and clears automatically when the error is fixed.

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour. Plugins can resolve imports, load custom file formats, compile files to JS and CSS, extract imports for dependency tracking, transform compiled code with OXC ASTs, inject compile-time definitions, customize vendor prebundling, and render final output chunks.

Plugins can also run JavaScript build tools through `Volt.JS.Runtime`, which installs npm packages into Volt's cache and executes bundled runtime code through QuickBEAM without requiring Node.js in the host application.

See [Plugins](plugins.md) for the full hook API and examples.
