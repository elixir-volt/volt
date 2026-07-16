# Changelog

## 0.17.7 - 2026-07-16

### Improved

- Render splice-only private templates through OXC's native pipeline to avoid repeated ESTree serialization for large generated entries.

## 0.17.6 - 2026-07-16

### Fixed

- Describe production build results with their strict `Volt.Builder.Result`, `ManifestEntry`, and `OutputFile` struct types.

## 0.17.5 - 2026-07-13

### Added

- Pass configured Oxlint environments to OXC linting.

## 0.17.4 - 2026-07-13

### Added

- Allow formatter and linter file discovery to override build `:root`, `:sources`, and `:ignore` independently.

## 0.17.3 - 2026-07-13

### Added

- `Volt.Builder` accepts importer-scoped package directories through `:package_scopes`.
- `Volt.NPM.install!/2` exposes isolated, npm_ex-backed package acquisition for frameworks and plugins.
- `Volt.Priv.render!/4` applies literal bindings and AST splices while preserving TypeScript for a subsequent Volt build.

### Fixed

- Preserve importer package scopes while resolving transitive package imports.
- Invalidate cached `Volt.Priv` templates and compiled modules when their source changes.
- Type-check the private test-entry splice placeholder without changing rendered output.

### Changed

- Require Elixir 1.18 and Erlang/OTP 27, and verify those minimum versions in CI.

## 0.17.2 - 2026-07-13

### Added

- `Volt.Priv.js!/4` accepts AST-backed statement, property, and array-element splices for private JavaScript and TypeScript templates.

### Changed

- Generate configured JavaScript test imports from a private TypeScript template instead of concatenating virtual-entry source.

## 0.17.1 - 2026-07-13

### Fixed

- Execute configured JavaScript test `setup_files` before each test module in both QuickBEAM and browser runners.
- Resolve `volt:test` APIs through true virtual module IDs so they remain resolvable from virtual test entries.

## 0.17.0 - 2026-07-10

### Added

- Add built-in Rust-native Sass and SCSS compilation for `.sass`, `.scss`, `.module.sass`, and `.module.scss` files, including relative partial imports and CSS hot replacement.

### Changed

- Upgrade Vize to `~> 0.14.0`, QuickBEAM to `~> 0.10.20`, and JSONCodec to `~> 0.2.3`.

### Fixed

- JavaScript tests that throw ordinary errors without assertion details now return structured failures instead of failing result decoding.

## 0.16.0 - 2026-07-10

### Changed

- `Volt.DevServer` now starts and supervises its file watcher automatically on the first development request, so Phoenix applications no longer need a `Mix.Tasks.Volt.Dev` endpoint watcher entry.

### Fixed

- Tailwind input CSS changes now rebuild before broadcasting a style update instead of being compiled as ordinary CSS and showing a browser error overlay.
- The vanilla LiveView example no longer marks its entry module as self-accepting, avoiding duplicate `LiveSocket` initialization during JavaScript updates.

## 0.15.5 - 2026-07-07

### Added

- Production builds now bundle eligible multi-entry ESM script inputs together and emit Rolldown shared chunks, deduplicating modules imported by multiple entries while preserving manifest imports.

### Changed

- Upgrade OXC to `~> 0.17.2`, QuickBEAM to `~> 0.10.19`, and npm_ex to `~> 0.7.5`.

## 0.15.4 - 2026-07-06

### Fixed

- Tailwind stylesheet and module resolution now searches Phoenix-style asset locations such as `deps` and `Mix.Project.build_path()`, fixing `phoenix-colocated/*/colocated.css` imports in fresh Phoenix projects.
- Dev-mode Tailwind rebuilds now watch generated Phoenix colocated CSS and perform full CSS rebuilds when imported stylesheets change.

## 0.15.3 - 2026-07-06

### Added

- Added `Volt.Test.Case` for inline ExUnit assertions against JavaScript and TypeScript snippets using `assert ~JS`, `assert ~TS`, `assert ~JSX`, and `assert ~TSX`.

## 0.15.2 - 2026-07-06

### Fixed

- Builder and dev-server resolution now preserve package import specifiers such as `#client/constants`, fixing packages that use nearest-package `imports` maps, including Svelte's browser runtime internals.

## 0.15.1 - 2026-07-06

### Added

- `Volt.Builder.bundle/1` returns in-memory bundles from Volt's normal Builder graph for test runners and other tooling that need executable JavaScript without production output files.
- Volt JavaScript tests now use Builder-backed bundling, so test files can use normal Volt bundle options through `bundle: [...]`, including plugins, aliases, `node_modules`, and `resolve_dirs`.

### Changed

- Removed the separate `Volt.Test.Bundler` layer in favor of `Volt.Builder.bundle/1`.
- Browser test execution now loads large test bundles from temporary script files instead of sending bundle source through Playwright protocol arguments.

## 0.15.0 - 2026-07-06

### Added

- ExUnit-native JavaScript and TypeScript tests through `Volt.Test.ExUnit.install/1`; `mix test` remains the single test entry point.
- `volt:test` runtime with `describe`, `test`/`it`, skip/todo modifiers, hooks, async tests, `test.each`, `describe.each`, and common `expect` matchers.
- Browser JavaScript tests with `browser: true` through PlaywrightEx.
- Strict `JSONCodec` result contracts for JavaScript test metadata, failures, and file results.
- OXC-backed source line discovery for registered JavaScript tests.
- JavaScript/TypeScript test fixture sigils in `Volt.Test.Sigils`.
- Phoenix example app tests that showcase Volt's Vitest-like test API.
- Browser dogfood coverage for Volt client overlay, preload, hot-context, and style-update runtime helpers.

### Changed

- Organized Volt TypeScript runtime and declaration files by purpose under `priv/ts` and `priv/types`.
- Split Volt test runtime TypeScript into focused modules.
- Split large builder and dev-server test files into feature-focused test modules.
- Mutable/generated test fixtures now use temporary directories instead of persistent fixture roots.
- Type-aware JavaScript checks keep Oxlint-shaped `:rules` config while avoiding unsupported `tsgolint` rules.
- Solid runtime bundling now uses explicit Node builtin shims instead of a global CommonJS `require` preamble.
- Development HMR client and CSS update support now use shared bundled client modules.

### Fixed

- Playwright integration tests can use the local `node_modules/.bin/playwright` executable.
- Phoenix example integration tests prepare example Mix/npm dependencies before asserting vendor and production build behavior.
- Browser console forwarding now decodes payloads through a strict `JSONCodec` contract.

## 0.14.12 - 2026-06-28

### Added
- `Volt.Assets.resolve/2` and `Volt.Assets.resolve!/2` resolve asset source specifiers through Volt aliases, root-relative paths, relative importers, and extension probing.

## 0.14.11 - 2026-06-27

### Added
- `Volt.Priv` reads OTP `priv` files and emits browser JavaScript from bundled JavaScript or TypeScript support modules.

### Changed
- Volt's internal browser support assets now use `Volt.Priv`.

## 0.14.10 - 2026-06-27

### Added
- `Volt.Path.relative_import/2` builds normalized relative JavaScript import specifiers between files.

## 0.14.9 - 2026-06-26

### Added
- Plugins can expose real-file-derived embedded modules through `Volt.Plugin.EmbeddedModule` query ids for custom file formats.
- Embedded script and style modules participate in production builds, dev serving, CSS handling, JavaScript checks, and HMR invalidation.

## 0.14.8 - 2026-06-25

### Added
- `Volt.HMR` exposes public helpers for external dev servers to broadcast HMR updates, style updates, full reloads, and errors.
- `Volt.Builder` can now use plugin-resolved virtual modules as production build entries.
- `Volt.DevServer` can now rewrite and serve plugin-loaded virtual modules in development.
- Plugin `load/1` two-tuple returns (`{:ok, code}`) are treated as JavaScript, making extensionless virtual modules work consistently in dev and production.
- `Volt.Watcher` supports generic `:reload_dirs` for external source directories that should trigger a full browser reload.
- `Volt.HMR.invalidate_file/1` lets external integrations evict Volt dev compilation state without broadcasting.

### Changed
- `Volt.DevServer` pass-through behavior is covered for composition with downstream HTML/site plugs.
- MIME/content-type lookup is centralized through `Volt.MIME`, backed by the `mime` package.

## 0.14.7 - 2026-06-23

### Added
- `:hmr_timeout` option on `Volt.DevServer` (and the `:server` config profile) controls the HMR websocket idle timeout. Defaults to `60_000`ms.
- CSS `@import` and `url()` relationships are now tracked through Vize's parser-backed CSS selectors so HMR can invalidate and hot-swap stylesheets, CSS modules, and framework-emitted styles when an imported stylesheet or referenced asset changes.
- CSS dependency tracking now resolves extensionless local imports to `.css` files and directory imports to `index.css` files.
- Svelte-emitted styles participate in CSS asset dependency tracking for HMR.

### Changed
- CSS dependency graph updates for physical CSS, CSS modules, and framework-emitted styles now flow through one HMR path.
- HMR websocket messages (`ping`, `pong`, `update`, `error`) now flow through `Volt.HMR.Message`, which uses `JSONCodec` for struct<->JSON (de)serialization with `Jason` performing the final binary encoding.
- Added `json_codec` as a runtime dependency.

### Fixed
- Cyclic CSS import graphs no longer report the changed stylesheet as its own HMR dependent.
- CSS module and framework-emitted style dependency links are removed when styles stop referencing an asset.
- HMR websocket no longer drops idle connections after 60 seconds. The browser client now sends a periodic `{"type":"ping"}` heartbeat, and the server replies with `{"type":"pong"}`, preventing Bandit's websocket `read_timeout` from closing an otherwise idle socket. The client also tracks pongs and force-reconnects if the link goes half-open. This eliminates the spurious `[Volt] Disconnected. Reconnecting...` console noise observed on long-lived demo/dev pages with no file changes.

## 0.14.6

### Changed

- Upgraded `oxc` to 0.17.1 and `quickbeam` to 0.10.18.
- Dynamic import variable rewriting and CommonJS `require()` import extraction now use parser-backed OXC selectors instead of full AST parse/postwalk passes.

## 0.14.5

### Changed

- Production bundle post-processing now rewrites CSS dynamic imports, CommonJS `require()`, and chunk import specifiers in a single parser pass, reducing repeated OXC parses for large dependency graphs.

## 0.14.4

### Changed

- Upgraded `oxc` to 0.17.0, `vize` to 0.13.0, and `quickbeam` to 0.10.17.
- Updated development and test dependencies, including Bandit, Credo, ExDNA, ExDoc, ExSlop, Floki, Igniter, Playwright, Sourceror, Spitfire, and Thousand Island.
- JavaScript and CSS scanning now uses parser-backed selector APIs for import, asset URL, worker, glob import, and `import.meta.env` discovery.

## 0.14.3

### Fixed

- CSS asset URL rewriting now uses Vize's parser-backed source rewrite API, avoiding LightningCSS AST print failures on Monaco Editor CSS while preserving font asset hashing.

### Changed

- Upgraded `vize` to 0.12.0.

## 0.14.2

### Fixed

- Production builds now rewrite CommonJS `require()` specifiers so bundled browser output does not leak runtime `require()` calls.
- Development vendor prebundle scanning now skips dependency/build directories such as `node_modules`, avoiding slow dev asset requests in apps with local npm installs.
- React, React DOM, and Solid framework proxy modules now derive public exports from the installed packages instead of hardcoded export lists.

### Changed

- Centralized common JavaScript extension and Volt path defaults.

## 0.14.1

### Fixed

- Development vendor prebundling now uses one multi-entry OXC bundle so shared singleton dependencies, such as CodeMirror packages, are loaded only once.
- Development vendor chunk files emitted by the optimizer are now served from the vendor cache.

### Changed

- Upgraded `oxc` to 0.16.0 and `quickbeam` to 0.10.16.

## 0.14.0

### Added

- `Volt.static_path/2` and `Volt.static_url/2` resolve Volt-managed scripts, stylesheets, and emitted image/font assets with Phoenix-style helper names.
- `mix volt.build --tailwind` now writes a CSS manifest using the existing production manifest format.

### Deprecated

- `Volt.entry_path/2` is deprecated in favor of `Volt.static_path/2`.

### Fixed

- `mix volt.js.check --type-aware --type-check` now fails on TypeScript compiler diagnostics such as `typescript/TS2322`.
- `mix volt.build --tailwind` now honors `hash: false` from Volt config for Tailwind CSS output filenames, while keeping CLI `--hash`/`--no-hash` overrides.

## 0.13.1

### Fixed

- `mix volt.js.check --type-aware` now forwards only `typescript/*` rules to `tsgolint`, matching Oxlint's type-aware rule namespace and avoiding crashes when normal oxlint category rules such as `"correctness"` are configured.

## 0.13.0

### Added

- `env_prefix` config for choosing which `.env` variables are exposed through `import.meta.env`, including Vite-compatible prefixes like `"VITE_"`.
- `asset_url_prefix` config and `mix volt.build --asset-url-prefix` for changing production JavaScript and CSS asset URLs without changing Phoenix output paths.
- Production chunk manifests now include richer chunk metadata: `imports`, `dynamicImports`, chunk-local `css`, and emitted `assets`.
- Plugin `embedded_modules/3` hook for exposing JavaScript-like scripts embedded in custom file formats.

### Changed

- Upgraded `oxc` to 0.15.1, `quickbeam` to 0.10.15, and `reach` to 2.6.1.
- `mix volt.js.check` now supports `--type-aware` and `--type-check` for TypeScript-aware linting through `tsgolint`.
- Type-aware checks now analyze Vue and Svelte component scripts via plugin-provided virtual modules while leaving templates on the normal syntax lint path.
- Production builds now tree-shake JavaScript by default, with `tree_shaking: false` and `mix volt.build --no-tree-shaking` available to preserve unused exports.
- Code-split dynamic imports now preload dependency chunks and chunk-local CSS when doing so avoids loading waterfalls.
- Code-split production builds now preserve dynamic import facades, rewrite chunk imports by exact resolved specifier, and avoid worker filename collisions.
- HMR boundary lookup now uses a served module graph, with a dedicated glob graph for `import.meta.glob()` invalidation.
- HMR updates now support self-accepting modules, dependency accept callbacks, multi-dependency accept callbacks, disposal data, CSS import updates, and full-reload fallback more closely to Vite's behavior.
- Production builds now write the final merged manifest once after all entries are built.
- Production JavaScript asset URL imports now emit hashed files and include them in manifest asset metadata.
- Worker build failures now fail the parent build instead of being ignored.
- JavaScript runtime installs now validate package signatures for reused install directories, and named runtimes reject option mismatches.
- `glob_ex` is now a direct dependency for HMR glob invalidation.
- Volt now dogfoods type-aware JavaScript checks in `mix lint`.

### Breaking changes

- Custom plugins that return `{:proxy, filename, opts}` from `prebundle_entry/1` must use `Volt.JS.PrebundleEntry.Import` and `Volt.JS.PrebundleEntry.Export` entries for `:imports` and `:exports`; plain map entries are no longer accepted.
- Custom `extract_imports/3` plugin callbacks must return `{:ok, %Volt.JS.ImportExtractor.Result{}}` instead of plain maps.

## 0.12.0

### Added

- Vite-compatible asset query imports for `?raw`, `?url`, `?inline`, and `?no-inline` in development and production builds.
- Production `new URL("./asset.ext", import.meta.url)` asset rewriting through generated asset URL imports.
- Expanded `import.meta.glob` support, dynamic import variable rewriting, and glob importer invalidation during HMR updates.
- Optional Vite-style public directory support for projects that want public-root compatibility.
- Vite-style plugin `enforce` ordering for `:pre`, normal, and `:post` hooks.

### Changed

- CSS asset URL rewriting now uses Vize/LightningCSS AST mutation and printing instead of source-range patching.
- JavaScript emitted by plugins and framework compilers now re-enters Volt's common post-processing pipeline.
- Upgraded `vize` to 0.11.1 and QuickBEAM to 0.10.14.
- Documented CSS-emitting plugins and OXC-backed template generation patterns.

### Fixed

- CSS-referenced assets are copied once per source asset, preserve query and fragment suffixes, and are included in build metadata.
- Asset import module identity now preserves query modes, avoiding collisions when the same file is imported with different asset queries.
- Mutating JavaScript post-processing steps now drop stale sourcemaps instead of returning mismatched maps.
- Dynamic import rewriting now preserves query suffixes.

## 0.11.3

### Fixed

- Watcher no longer caches its own compilation results, preventing stale responses missing HMR preamble, `import.meta.env` injection, and dev import rewriting after file changes.
- CSS `?import` cache entries are now properly evicted on file changes.

## 0.11.2

### Fixed

- Tailwind `@plugin "daisyui"` and subpath imports like `daisyui/theme` now resolve correctly.
- Tailwind `@import "tw-animate-css"` now resolves via the `style` export condition.

## 0.11.1

### Added

- `module_types` config option — maps file extensions to bundler loaders (e.g. `%{".css" => :empty, ".ttf" => :empty}`). Passed to both production builds and vendor prebundling. Useful for packages like Monaco Editor that import non-JS files.

### Changed

- Upgraded OXC to 0.13 and QuickBEAM to 0.10.13.

## 0.11.0

### Added

- Named configuration profiles for multi-app and umbrella support. Use `config :volt, :my_app_web, [...]` to define per-app configs, and pass the profile name to Mix tasks (`mix volt.build my_app_web`) and the dev server plug (`plug Volt.DevServer, profile: :my_app_web`). The existing flat `config :volt` format continues to work unchanged.

## 0.10.9

### Fixed

- `mix volt.build` now compiles the project and starts only Volt's application, avoiding database connection attempts during asset builds in Phoenix projects while keeping Volt services available for Tailwind builds.

## 0.10.8

### Fixed

- `mix volt.build` now compiles the project without starting the application, avoiding database connection attempts during asset builds in Phoenix projects.

## 0.10.7

### Added

- Vendor prebundling and dev-server on-demand bundling now honor `resolve_dirs`, allowing bare imports to resolve from additional module directories such as Phoenix's `_build/$MIX_ENV/phoenix-colocated` output.
- Documented the Phoenix LiveView colocated JavaScript setup for projects migrating from esbuild's `NODE_PATH` configuration.

### Changed

- Upgraded the Tailwind CSS runtime package requirement to `^4.3.0`.
- `mix ci` now runs the test suite through `env MIX_ENV=test`, which works with newer Mix versions.

### Fixed

- Additional resolve directories now support package-like folders without `package.json`, including subpath imports such as `phoenix-colocated/my_app`.

## 0.10.6

### Added

- Dev server output now supports `import.meta.env` runtime access for modules that reference it, including `MODE`, `DEV`, `PROD`, and exposed `VOLT_*` values.

### Fixed

- `Volt.entry_path/2` now resolves production manifests written by `mix volt.build` under `priv/static/assets/js`, returns `/assets/js/...` paths, and passes them through Phoenix `static_path/1` for `phx.digest` compatibility.
- Production entry path lookup now resolves relative `priv/...` output directories through the endpoint OTP app, matching Phoenix release behavior.

## 0.10.5

### Added

- Solid JSX/TSX support via `Volt.Plugin.Solid`. Runs `babel-preset-solid` through QuickBEAM — no Node.js required. Enable with `plugins: [Volt.Plugin.Solid]` in Volt config.
- Solid example app under `examples/solid`.

### Changed

- Upgraded QuickBEAM to 0.10.12.

### Fixed

- Tailwind plugins using `fs.readFileSync(path).toString()` (like `heroicons.js`) now produce correct UTF-8 strings instead of comma-separated ASCII char codes. Root cause was in QuickBEAM's `fs.readFileSync` returning raw `Uint8Array` instead of `Buffer`.

## 0.10.4

### Fixed

- CSS files imported from JavaScript (`import './style.css'`) are now served as JavaScript modules that inject styles at runtime, matching Vite's behavior. Previously the dev server returned `text/css`, which browsers rejected as an invalid ES module MIME type.
- CSS Modules (`.module.css`) are now served as JavaScript in the dev server regardless of how they are requested, fixing silent failures when importing CSS modules from JS.
- CSS import specifiers in JS are rewritten to `?import` URLs so the dev server can distinguish stylesheet requests from JS module imports and serve each with the correct content type.

### Added

- `updateStyle` and `removeStyle` helpers in the HMR client for injecting and removing `<style>` tags by module ID.
- HMR style updates now refresh injected CSS import modules in addition to `<link>` stylesheet tags.

## 0.10.3

### Changed

- Upgraded `npm_ex` to 0.7.1 and QuickBEAM to 0.10.11.
- Runtime npm installs now record and validate npm_ex lockfile security policy, including registry allowlists, registry redirect policy, and transitive exotic dependency policy.
- QuickBEAM now hides vendored C symbols in the native library to avoid collisions with other NIFs.

### Security

- Runtime npm installs continue to ignore package lifecycle hooks and now warn when packages declare ignored install scripts.
- `npm_ex` now blocks direct git/file/URL dependencies unless explicitly allowlisted and blocks transitive exotic dependency specs from registry metadata by default.
- `npm_ex` now skips package versions with blocked transitive exotic dependencies during resolution, so safe matching versions can still be selected.

## 0.10.2

### Changed

- Upgraded OXC toolchain to 0.12.0 (OXC Rust crates 0.117 → 0.129: 12 releases of parser, transformer, minifier, codegen, formatter, and linter improvements).
- Upgraded Tailwind CSS Oxide scanner to v4.2.4 (was v4.1.8).
- Upgraded QuickBEAM to 0.10.9.
- Upgraded Reach to 2.0.
- Bumped 9 other dependencies to latest versions.

## 0.10.1

### Added

- Added `makeup_js` dependency for JavaScript syntax highlighting in hexdocs.
- Expanded plugins guide with five practical examples: Markdown imports, banner injection, build-time constants, CSV compilation, and AST transforms with OXC.

### Fixed

- Fixed missing syntax highlighting for JavaScript code blocks in guides.

## 0.10.0

### Added

- Added `custom_renderer` config option for Vue Vapor renderer-native elements.
- Added `guides/` documentation with 16 pages organized into Introduction, Features, Deployment, Migration, and Cheatsheets sections.
- Added dedicated framework guide covering React, Vue, and Svelte setup.
- Hexdocs now includes `groups_for_modules`, `groups_for_extras`, and CHANGELOG.
- Framework examples now demonstrate JSON imports, SVG asset imports, `import.meta.glob()`, `import.meta.env`, `import.meta.hot`, multi-component structure, and Tailwind CSS.
- Examples now use `Volt.Formatter` and `mix volt.lint` with framework-appropriate plugins.

### Changed

- Upgraded Vize from 0.8 to 0.10. Vue SFC TypeScript stripping now uses Vize's `strip_types` option in a single NIF call instead of a separate OXC transform pass.
- Increased Svelte compiler stack size from 8 MB to 16 MB to handle real-world component complexity.
- README slimmed from 514 lines to ~80 lines; reference content moved to guides.

### Fixed

- `import.meta.glob()` now works in `.tsx` files (was hardcoded to parse as `.ts`).
- `import_source` config (e.g. `"react"`) is now passed through to production builds, fixing JSX transform in `mix volt.build`.
- Static asset imports (SVG, images) no longer crash the production builder.
- CSS Modules (`.module.css`) now work in production builds — fixed resolver, collector, and bundler label handling.
- CSS Modules JS output uses a variable assignment to avoid ambiguous `export default {}` parsing in the bundler.
- `mix volt.lint` no longer attempts to parse `.svelte` and `.vue` files as JavaScript.
- Build config `format:` is no longer clobbered by formatter config `config :volt, :format`.
- Code-split builds now include alias-resolved modules outside the entry root.
- Dynamic CSS imports in production builds now resolve to inert fulfilled promises instead of runtime CSS module imports.
- Minified code-split builds now rewrite dynamic imports emitted as static template literals to generated chunk files.

## 0.9.2

### Fixed

- Code-split builds now preserve the real entry chunk when the entry contains dynamic imports.
- Per-chunk bundle failures now surface as build errors instead of producing manifests that point entries at async chunks.
- Empty and CSS-only JS entries now build successfully when source maps are enabled and Rolldown omits a map.
- `mix volt.build` documentation now uses the supported `--sourcemap false` CLI form for disabling production source maps.

## 0.9.1

### Added

- Vue compile-time feature flags are now provided by the built-in Vue plugin.
- `process.env.NODE_ENV` is now defined automatically from Volt's build mode.

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

```javascript
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

```javascript
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
