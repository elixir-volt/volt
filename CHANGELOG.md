# Changelog

## 0.9.0

### Added

- Added `Volt.entry_path/2` for resolving source entries in development and hashed manifest assets in production.
- Added built-in React prebundle coordination for React, React DOM client, and JSX runtime imports.
- Added plugin prebundle hooks for canonical dependency aliases and generated proxy entries.
- Added Vue, Svelte, and React example Phoenix apps.
- Added built-in Svelte support, including prebundle coordination for `svelte` and `svelte/internal/client` through a single runtime bundle.

### Changed

- Vendor prebundling now uses filesystem entries through OXC with browser conditions, named exports, and strict entry signatures.
- Updated dependencies to QuickBEAM 0.10.6 and OXC 0.11.0.
- Replaced the old demo app with focused framework examples.

### Fixed

- Package imports using `#` specifiers now resolve in both dev server rewriting and production builds.
- Production entry paths now read Volt's manifest output through a first-class helper instead of requiring app-local layout helpers.

## 0.8.4

### Fixed

- Tailwind CSS builds now resolve relative `@plugin` and `@import` paths correctly from the CSS file's directory (`css_base` option propagated from all callers).
- QuickBEAM builtins (`fs`, `path`, `process`, etc.) are now available to CJS vendor plugins loaded by the Tailwind runtime.
- Bundled CJS plugins with `__esModule` + `.default` (e.g. daisyui) are now unwrapped so Tailwind v4 receives the plugin function directly.
- `mix igniter.install volt` now auto-detects `assets/js/app.js` vs `assets/js/app.ts` instead of hardcoding `.ts`.

## 0.8.3

### Fixed

- `mix igniter.install volt` now fully removes legacy esbuild and tailwind configuration:
  - Deletes `config :esbuild` and `config :tailwind` blocks from `config/config.exs` and `config/dev.exs`.
  - Removes `esbuild:` and `tailwind:` watchers from the endpoint `watchers` list in `config/dev.exs`.
  - Updates mix aliases so `assets.setup`, `assets.build`, and `assets.deploy` no longer reference removed tasks.

### Changed

- Refactored `Mix.Tasks.Volt.Install` for readability: added module aliases, extracted predicate helpers, flattened nested control flow.

## 0.8.2

### Added

- `Volt.Formatter` — `mix format` plugin for JS/TS. Add `plugins: [Volt.Formatter]` to `.formatter.exs` and JS/TS files are formatted alongside Elixir with oxfmt.
- `mix igniter.install volt` now adds `Volt.Formatter` to `.formatter.exs` automatically.

### Fixed

- Dev server now pre-bundles vendor dependencies on startup and bundles on demand as fallback — bare imports like `react` no longer 404 at `/@vendor/`.
- CJS packages (e.g. React 19) are bundled as ESM via `OXC.bundle` with `format: :esm`. Conditional `process.env.NODE_ENV` branches resolve correctly.
- Cross-package CJS `require()` calls (e.g. `react-dom` requiring `react`) are rewritten to ESM imports pointing at other `/@vendor/` modules via AST.

## 0.8.1

### Added

- Configurable file discovery via `sources:` and `ignore:` in `config :volt`. Default sources: `["**/*.{js,ts,jsx,tsx,vue}"]`, default ignore: `["node_modules/**", "vendor/**"]`.

### Changed

- Unified file discovery across `volt.js.format`, `volt.js.check`, and `volt.lint` — all use the same `sources` and `ignore` config.

## 0.8.0

### Added

- `mix volt.js.format` — format JS/TS assets with oxfmt via NIF. No Node.js required.
- `mix volt.js.check` — format check + lint in one command via NIF.
- `mix volt.install` — Igniter-based project setup. Adds Volt config, dev server plug, watcher, removes esbuild/tailwind deps. Migrates existing Prettier/oxfmt JSON config.
- `config :volt, :format` — Elixir-native format config (falls back to `.oxfmtrc.json`).

### Changed

- Replaced npx-based formatting/linting with NIF bindings (no Node.js needed).
- Format and lint tasks use `app.config` instead of `app.start` (no full app boot required).
- File discovery uses `config :volt, :root` consistently across format, check, and lint tasks.
- Renamed `mix volt.js.fmt` → `mix volt.js.format`.

## 0.7.1

- Improve `mix volt.lint` output to match credo style — grouped by category, severity tags, edge markers, summary by category

## 0.7.0

### Added

- `mix volt.lint` — lint JS/TS/JSX/TSX/Vue assets with oxlint's 650+ built-in rules via NIF. No Node.js required. Configurable plugins, rules, and custom Elixir lint rules via `config :volt, :lint`.

## 0.6.5

### Added

- Strip TypeScript types from Vue SFCs with `<script lang="ts">` after Vize compilation
- Resolve `import './types.js'` to `./types.ts` when the `.js` file doesn't exist (standard TS convention)
- Resolve bare specifiers in directories without `package.json` (e.g. Phoenix colocated hooks via `resolve_dirs: [Mix.Project.build_path()]`)

### Fixed

- Fix Vue SFC compiler-injected `vue` imports being externalized in SSR bundles — bare specifiers introduced by Vize are now resolved via a global fallback map
- Fix JSON module imports crashing OXC.bundle — `.json` labels are renamed to `.json.js` so Rolldown treats the `export default` wrapper as JavaScript
- Skip JSON files in import extraction (they have no imports)

## 0.6.4

### Added

- `loaders` option for overriding file type parsing (e.g. `loaders: %{".js" => "jsx"}` for React projects that use JSX in `.js` files)
- CJS `require()` calls are now collected as imports during dependency walking

### Fixed

- Fix bare specifier subpath resolution when package has no `exports` field (e.g. `iframe-resizer/js/iframeResizer`) — falls back to direct file path instead of returning the package main entry
- Skip `.d.ts` type declaration imports instead of raising not-found errors
- Skip CSS imports (`import './app.css'`, `@fontsource/inter`, etc.) during JS bundling — CSS files are no longer collected, resolved, or passed to OXC.bundle
- Fix files from `resolve_dirs` getting absolute path labels that break import rewriting

### Performance

- Use `OXC.collect_imports` (Rust NIF) for 98% of modules instead of `parse` + `postwalk` JSON round-trip — 2.5x faster collection
- Use `OXC.transform_many` (rayon thread pool) for parallel module compilation — 3x faster on large projects
- Livebook (2045 modules): 9s → 1.8s; Plausible Analytics dashboard: 5s → 1.2s

## 0.6.3

### Bug Fixes

- Fix bundling packages with internal relative imports (reka-ui, @internationalized/date, etc.) — labels now preserve directory structure relative to node_modules, and import rewriting uses per-file specifier maps instead of a global map that conflated identical relative specifiers from different importers
- Fix `CaseClauseError` when an alias resolves to a missing file — `NPM.PackageResolver.try_resolve` returning bare `:error` is now wrapped into `{:error, {:not_found, path}}`
- Bump `oxc` to 0.7.1 (fixes `parse/2` hitting serde_json recursion limit on large ASTs)

## 0.6.2

### Bug Fixes

- Fix infinite label dedup loop when multiple modules import the same
  dependency (e.g. `@vue/shared` imported by both `@vue/runtime-core`
  and `@vue/reactivity`) — the second import no longer triggers label
  disambiguation, preventing mangled paths like `dist/dist/@vue/shared_2`

## 0.6.1

### Bug Fixes

- Fix plugin `content_type` being ignored — when a plugin returned
  `{:ok, code, "application/javascript"}` for a `.vue` file, Pipeline
  still ran Vue SFC compilation on the already-compiled JS
- Fix virtual modules (`resolve` → `"virtual:..."`) failing with
  `:enoent` — Collector now calls plugin `load` before `File.read`
- Fix duplicate label crash when multiple files share the same basename
  (e.g. `a/index.js` and `b/index.js`) — labels are disambiguated with
  parent directory prefix and recursive `_2` suffix fallback
- Thread plugin `content_type` through Collector so import extraction
  dispatches consistently with Pipeline

## 0.6.0

### Per-Module ESM Dev Server with HMR

The dev server now serves individual ESM modules instead of opaque compiled
files. Each `.ts`, `.vue`, `.jsx` file gets its own URL, and import specifiers
are rewritten so the browser resolves the full module graph natively:

- Relative imports (`./utils`) → `/assets/utils.ts`
- Bare imports (`vue`) → `/@vendor/vue.js` (pre-bundled)
- Alias imports (`@/utils`) → resolved via tsconfig paths or config aliases

Each JS module is injected with an `import.meta.hot` preamble for granular HMR:

```typescript
if (import.meta.hot) {
  import.meta.hot.dispose(() => clearInterval(timer));
  import.meta.hot.accept();
}
```

On file change, the watcher walks the dependency graph upward to find the
nearest `import.meta.hot.accept()` boundary. Only that module is re-imported
via `import("/@assets/Button.tsx?t=123")` — no full page reload. Accept
callbacks receive the new module exports. Falls back to `location.reload()`
when no boundary is found.

TypeScript assets (HMR client, console forwarder, error overlay) are now
compiled to JS via OXC before serving to the browser.

### Production Source Maps

Source maps are now fully usable in production builds:

- `sourcemap: true` — write `.map` files and append `//# sourceMappingURL` (default)
- `sourcemap: :hidden` — write `.map` files without the URL comment (for Sentry, Datadog)
- `sourcemap: false` — no source maps
- Chunked builds now generate source maps (previously discarded)
- CLI: `--sourcemap hidden`

### tsconfig.json Paths

Volt automatically reads `compilerOptions.paths` from `tsconfig.json` in the
project root and merges them into aliases. Explicit aliases take precedence.
Supports `baseUrl` for path resolution.

### Manual Chunk Splitting

Control chunk boundaries via config:

```elixir
config :volt,
  chunks: %{
    "vendor" => ["vue", "vue-router", "pinia"],
    "ui" => ["assets/src/components"]
  }
```

Bare specifiers match package names in `node_modules`. Path patterns match by
directory prefix. Manual chunks work alongside automatic dynamic-import splitting.

### Bug Fixes

- Fix alias-imported Vue SFCs silently dropping bare npm imports from the bundle

### Internal

- Reorganize internal modules into `Volt.JS.*`, `Volt.CSS.*`, `Volt.Dev.*` namespaces
- Add Playwright browser integration tests (`mix test --include integration`)

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

- Upgrade `oxc` to `~> 0.7.0` (Rolldown-backed bundling, `rewrite_specifiers/3`, snake_case AST types)
- Upgrade `quickbeam` to `~> 0.10.0`
- Upgrade `npm` to `~> 0.5.3` (shared `NPM.PackageResolver`)

### Bug Fixes

- Fix duplicate identifier collision when bundling npm packages — bare
  specifier labels are now rewritten to relative paths for Rolldown

- Fix `Preload.tags/2` returning empty output (was filtering map values as strings)
- Fix ETS table race condition — `Cache` and `DepGraph` tables now created
  in `Application.start/2` instead of lazy init
- Fix Dialyzer warning on `Format.file_mtime/1` return type
- Add `Cache.entry` type field for `:hashes`
- Stop `FileSystem` processes in `Watcher.terminate/2`
- Accept `:created`/`:closed` file events in Watcher (not just `:modified`)
- Use per-test fixture directories in HMR tests to prevent race conditions

### Refactoring

- Delete `Volt.PackageResolver` — delegate to `NPM.PackageResolver`
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

- Fix duplicate identifier collision when bundling npm packages — bare
  specifier labels are now rewritten to relative paths for Rolldown

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
