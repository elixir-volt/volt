# Changelog

## 0.4.0

### External Globals

External imports now generate proper global variable access in the IIFE output
instead of being silently stripped. Supports both auto-derived and explicit names:

```elixir
config :volt, external: ["vue"]
# import { ref } from 'vue'  →  const { ref } = Vue;

config :volt, external: %{"vue" => "MyVue"}
# import { ref } from 'vue'  →  const { ref } = MyVue;
```

### CSS `@import` Inlining

CSS files with `@import` rules are bundled via LightningCSS's Bundler.
Imports are resolved recursively from disk with proper `@media`/`@supports`/`@layer` wrapping
and `url()` rebasing.

### HTML Entry Points

Entry files can now be HTML — `<script src="...">` tags are extracted
via Floki and used as JS entry points:

```bash
mix volt.build --entry index.html
```

### `import.meta.glob()`

Glob patterns are expanded at build time via OXC AST:

```typescript
const pages = import.meta.glob('./pages/*.ts')
// → { "./pages/home.ts": () => import("./pages/home.ts"), ... }

const eager = import.meta.glob('./pages/*.ts', { eager: true })
// → static imports with namespace bindings
```

### Module Preload

New `Volt.Preload.tags/2` generates `<link rel="modulepreload">` tags
from the build manifest for production chunk preloading.

### Build Size Reporting

Build output now shows gzip sizes:

```
app.js  128.4 KB (gzip: 38.2 KB)
```

### Bug Fixes

- **HMR**: Watcher cache lookup used mtime 0, so granular Vue SFC
  change detection (style-only updates) never worked. Fixed.
- **Vendor URLs**: Scoped packages (`@vue/shared`) had lossy URL encoding
  that broke round-trips. Now uses reversible encoding.
- **CSS errors**: Pipeline `compile_css` had no error clause and would
  crash on invalid CSS instead of returning an error.
- **`.env` parser**: Replaced hand-rolled parser with Dotenvy for correct
  handling of multiline values, variable expansion, and escaping.
- **IIFE injection**: External globals preamble injection now uses OXC AST
  to find the function body offset instead of fragile string splitting.
- **Chunk URLs**: Dynamic import rewriting matches by path suffix instead of
  basename to avoid collisions between same-named files in different directories.

### Internal Improvements

- Tailwind GenServer lazily initializes QuickBEAM runtime on first call
  instead of on application start
- Deduplicated `content_hash`, `file_mtime`, `derive_global_name`,
  `extract_vue_imports` across modules
- Vendor cache dir respects `MIX_BUILD_PATH`
- Tailwind bundle path uses `Application.app_dir` instead of compile-time
  `:code.priv_dir`
- HTML parsing uses Floki instead of regex
- Dependencies: oxc ~> 0.5.2, vize ~> 0.8.0, floki ~> 0.38, dotenvy ~> 1.1

## 0.3.0

### Code Splitting

Dynamic `import()` expressions are detected during the dependency walk and
split into separate async chunks. Shared modules between the entry chunk and
async chunks are extracted into a common chunk to avoid duplication.

### External Modules

New `:external` option excludes specifiers from the bundle.

### Centralized Configuration

All config now lives under `config :volt` in your standard `config/*.exs` files:

```elixir
config :volt,
  entry: "assets/js/app.ts",
  target: :es2020,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  aliases: %{"@" => "assets/src"},
  tailwind: [css: "assets/css/app.css", sources: [...]]
```

### Plugin System

`Volt.Plugin` behaviour with resolve, load, transform, render_chunk hooks.

### CSS Modules

`.module.css` scoped via LightningCSS. No regex.

### Static Assets, JSON Imports, Env Variables, Import Aliases

See README for full details.

### Builder Refactor

Split into `Volt.Builder.Resolver`, `Volt.Builder.Collector`,
`Volt.Builder.Output`, and `Volt.ChunkGraph`.

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
