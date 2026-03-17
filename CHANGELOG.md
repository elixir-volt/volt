# Changelog

## 0.3.0

### Code Splitting

Dynamic `import()` expressions are detected during the dependency walk and
split into separate async chunks. Shared modules between the entry chunk and
async chunks are extracted into a common chunk to avoid duplication.

```typescript
const admin = await import('./admin') // → app-admin-c3d4e5f6.js
```

### External Modules

New `:external` option excludes specifiers from the bundle. Essential for
Phoenix apps where `phoenix`, `phoenix_html`, and `phoenix_live_view` are
provided by the framework:

```elixir
config :volt, external: ~w(phoenix phoenix_html phoenix_live_view)
```

### Centralized Configuration

All config now lives under `config :volt` in your standard `config/*.exs` files,
following the same pattern as `phoenix`, `esbuild`, and `tailwind` hex packages:

```elixir
config :volt,
  entry: "assets/js/app.ts",
  target: :es2020,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  aliases: %{"@" => "assets/src"},
  tailwind: [css: "assets/css/app.css", sources: [...]]
```

Mix tasks and the DevServer plug read from config automatically.
CLI flags override for one-off use.

### Plugin System

New `Volt.Plugin` behaviour with four optional hooks:
- `resolve/2` — remap import specifiers
- `load/1` — provide virtual module content
- `transform/2` — modify compiled output
- `render_chunk/2` — modify final output chunks

### CSS Modules

`.module.css` files are scoped using LightningCSS (via Vize 0.7.0).
Class names, IDs, keyframes, and custom identifiers are properly scoped
through a real CSS parser — no regex.

### Static Asset Handling

Images, fonts, SVGs, and other non-code files are handled automatically.
Small files (< 4KB) are inlined as base64 data URIs. Larger files are
served directly in dev and copied with content-hashed filenames in prod.

### JSON Imports

`import data from './data.json'` compiles to `export default {...}`.

### Environment Variables

`.env` files are loaded and variables prefixed with `VOLT_` are available
as `import.meta.env.VOLT_*` in source code. Built-in `MODE`, `DEV`, and
`PROD` variables are always available.

### Import Aliases

```elixir
config :volt, aliases: %{"@" => "assets/src"}
```

`import { Button } from '@/components/Button'` resolves to the configured path.

### Multiple Entry Points

`--entry` flag is now repeatable for multi-page apps. Each entry produces
its own bundle and manifest entries.

### Builder Refactor

`Volt.Builder` split into focused submodules:
- `Volt.Builder.Resolver` — specifier resolution chain
- `Volt.Builder.Collector` — dependency graph walk with import type detection
- `Volt.Builder.Output` — chunk bundling, file writing, manifest
- `Volt.ChunkGraph` — chunk assignment from module dependency map

### Other Changes

- Config values use atoms (`:es2020`, `:production`) instead of strings
- DevServer serves static assets with correct MIME types
- `.json` recognized as compilable extension in DevServer and Builder
- Vize upgraded to 0.7.0 for CSS Modules support

## 0.2.0

- Fix circular dependency handling in OXC bundler
- Support nested export conditions in package.json
- Update to oxc 0.5.1, quickbeam 0.7.1

## 0.1.0

- Initial release
- Dev server with HMR
- JS/TS/Vue SFC compilation via OXC and Vize
- Tailwind CSS v4 integration
- Production builds with tree-shaking and content hashing
