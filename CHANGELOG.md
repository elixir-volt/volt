# Changelog

## 0.5.0

### Generic Tailwind Loader

Replaced the vendored `@tailwindcss/typography` bundle with a generic Tailwind
loader powered by QuickBEAM. Volt now resolves and prebundles any Tailwind
plugin or config file on the fly — no vendored JS blobs needed.

- `@plugin "./my-plugin.js"` — local plugins with full `require()` graph
- `@plugin "@tailwindcss/typography"` — npm package plugins
- `@config "./tailwind.config.js"` — local config files
- `@import "./extra.css"` and `@reference "./tokens.css"` — local stylesheets
- New `:css_base` option for resolving paths relative to input CSS

Module graphs are prebundled in Elixir via OXC's Rolldown-backed bundler,
so the JS runtime only evaluates self-contained CJS bundles.

### Dependencies

- Upgrade `oxc` to `~> 0.6.2` (Rolldown-backed bundling with `:entry` and `:format` options)
- Upgrade `quickbeam` to `~> 0.9.0`

### Bug Fixes

- Fix `Preload.tags/2` returning empty output (was filtering map values as strings)
- Fix ETS table race condition — `Cache` and `DepGraph` tables now created
  in `Application.start/2` instead of lazy init
- Fix Dialyzer warning on `Format.file_mtime/1` return type
- Add `Cache.entry` type field for `:hashes`
- Stop `FileSystem` processes in `Watcher.terminate/2`
- Accept `:created`/`:closed` file events in Watcher (not just `:modified`)
- Use per-test fixture directories in HMR tests to prevent race conditions

### Refactoring

- Split `Builder.Output` (370+ lines) into `Output`, `Writer`, `BundleResult`, `Rewriter`
- Extract `Tailwind.Loader` and `Tailwind.Resolver` from the Tailwind GenServer
- Consolidate package.json exports resolution into `PackageResolver` with
  parameterized condition order (browser-first vs CJS-first)
- Unify `try_resolve` with optional extension/index params across Builder and Tailwind
- Centralize specifier predicates (`relative?`, `absolute?`, `bare?`, `node_builtin?`)
  in `Builder.Resolver`
- Extract `Volt.Extensions` as single source for file extension lists
- Extract `WorkerRewriter.extract_specifier/1` to deduplicate worker URL
  pattern matching across Collector, WorkerRewriter, and Rewriter
- Remove duplicated `compile_vue`, `extract_vue_imports`, `try_resolve`,
  `content_hash`/`file_mtime` wrappers, `bare_specifier?`
- Reduce `Collector.do_collect` from 7 positional args to a state map
- Reduce `build_entry` from 9 positional args to 5 with a `build_ctx` map
- Reduce `build_chunks`/`build_single` args with shared `build_ctx`
- Extract `build_chunk_filenames` and `process_source` to reduce nesting depth
- Replace `throw`/`catch` in Tailwind loader with error accumulator
- Replace `stringify` helper with `maybe_put` in Pipeline
- Simplify `emit_global_access` accumulator in Externals
- Use `Keyword.take` allowlist in `Config.build`
- Use `String.replace_prefix` in `DevServer.strip_prefix`
- Add `Logger.debug` to `HMR.Socket.handle_in`
- Extract shared Mix task helpers into `Volt.JsHelpers`
- Rename `Builder.Assets` to `Builder.Writer` to avoid collision with `Volt.Assets`
- Add `@type rewrite_fn` to Pipeline
- Add `@moduledoc` to internal modules
- Document `Vendor.encode_specifier/1` and `decode_specifier/1`

## 0.4.2

- Fix fresh installs for Tailwind support by removing the generated `priv/tailwind.js` workflow
- Assemble the Tailwind runtime on first use from the `tailwindcss` package in the `npm_ex` cache
- Bump QuickBEAM to 0.8.0 and npm_ex to 0.5.1

## 0.4.1

### TypeScript Assets

Browser JavaScript (HMR client, error overlay, dev console forwarder) moved from
inline Elixir heredocs to separate TypeScript files in `priv/ts/`.
`Volt.JSAsset.read!/1` loads them at runtime.

### Maintainer Tooling

- `mix volt.js.check` — run oxfmt format check and oxlint via npx
- `mix volt.js.fmt` — format TypeScript assets via npx

### Tailwind Vendoring

The Tailwind runtime is now assembled from the `tailwindcss` npm package at runtime using the npm_ex cache. The runtime
shows a clear error if the file is missing.

### Build Improvements

- Structured manifest entries with `file`, `src`, `assets`, and `css` fields
- Standalone CSS entries in the manifest
- Worker entry groundwork
- Hardened package resolution with `browser`/`import`/`default`/`require` and CJS support
- Dev console forwarding from browser to terminal

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
const pages = import.meta.glob("./pages/*.ts");
// → { "./pages/home.ts": () => import("./pages/home.ts"), ... }

const eager = import.meta.glob("./pages/*.ts", { eager: true });
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
