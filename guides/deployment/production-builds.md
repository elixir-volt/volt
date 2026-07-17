# Production Builds

```bash
mix volt.build
```

```text
Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB
  manifest.json  2 entries
Built in 15ms
```

Reads configuration from `config :volt`. CLI flags override config values.

## What production builds do

Production builds run the same framework/plugin compilation pipeline as the dev server, then apply build-only graph and output steps:

- expands `import.meta.glob()` and simple relative dynamic import variables
- rewrites `new URL("./asset.ext", import.meta.url)` through the asset pipeline
- rewrites relative CSS `url(...)` asset references through the asset pipeline
- copies JavaScript- and CSS-referenced assets with content hashes
- tree-shakes, minifies, and optionally code-splits JavaScript
- writes a manifest that Phoenix can use for digested asset paths and chunk preload metadata
- optionally copies a Vite-style public directory to the static root without transforming files

## Public files in Phoenix apps

For Phoenix projects, stable root files usually belong in `priv/static` and are served by Phoenix through `Plug.Static`. Examples include `favicon.ico`, `robots.txt`, web app manifests, and touch icons. Keep those files at the Phoenix level when possible.

Volt handles files that are part of the frontend module graph instead:

- JavaScript asset imports
- `new URL("./asset.ext", import.meta.url)` references
Those graph assets are copied with content hashes and rewritten in production builds. CSS files are parsed and bundled by LightningCSS through Vize, and relative CSS `url(...)` references are rewritten through Vize's parser-backed CSS AST API. CSS-referenced emitted assets are listed on the CSS manifest entry.

## Optional Vite-style public directory

`public_dir` is disabled by default. Enable it only when you intentionally want Vite-style public directory behavior, for example during migration from Vite:

```elixir
config :volt,
  public_dir: "public"
```

When enabled, files are copied as-is to the static root. With the default output directory, JavaScript and CSS are written below `priv/static/assets`, while public files are copied to `priv/static`:

```text
public/favicon.svg      -> priv/static/favicon.svg
public/robots.txt       -> priv/static/robots.txt
assets/js/app.ts        -> priv/static/assets/js/app-a1b2c3d4.js
```

Reference public files with root-absolute URLs such as `/favicon.svg`. They are not transformed, hashed, or included in the module graph.

CLI: `mix volt.build --public-dir path/to/public`.

## Asset URL Prefix

Production JavaScript and CSS asset references use `/assets` by default, matching Phoenix's conventional `priv/static/assets` mount. Change only the public URL prefix with `asset_url_prefix`; this does not change the filesystem `outdir` or Phoenix endpoint/static URL configuration.

```elixir
config :volt, asset_url_prefix: "/my-app/assets"
```

CLI: `mix volt.build --asset-url-prefix /my-app/assets`.

## Tree Shaking

JavaScript tree shaking is enabled by default for production builds. Disable it only when you need to preserve unused exports or debug bundling output:

```elixir
config :volt, tree_shaking: false
```

CLI: `mix volt.build --no-tree-shaking`.

## Source Maps

- `sourcemap: true` — write `.map` files and append `//# sourceMappingURL` comment (default)
- `sourcemap: :hidden` — write `.map` files without the URL comment (for Sentry, Datadog, etc.)
- `sourcemap: false` — no source maps

CLI: `--sourcemap hidden` or `--sourcemap false`.

## External Modules

Exclude packages that the host page already provides:

```elixir
config :volt, external: ~w(phoenix phoenix_html phoenix_live_view)
```

Or per-build: `mix volt.build --external phoenix --external phoenix_html`

## Module Preloading

For code-split builds, the production manifest records static imports, dynamic imports, chunk-local CSS, and emitted assets. Use `Volt.Preload.tags/2` in your layout to preload the entry and its static chunk dependencies:

```heex
<%= Volt.Preload.tags("priv/static/assets/js/manifest.json", "/assets/js", entry: "app.js") %>
```

Runtime dynamic imports are rewritten through Volt's preload helper when the async chunk has dependency chunks or CSS. The helper preloads those files before executing `import()`, avoiding extra round trips while keeping async chunks lazy.

## Volt hashes and Phoenix digests

Volt and Phoenix have separate responsibilities in the default deployment pipeline:

1. Volt gives entries, chunks, CSS, and graph assets content-hashed filenames and records their relationships in its `manifest.json`.
2. `phx.digest` generates Phoenix's cache manifest, compressed copies, and final static filenames.
3. In production, `Volt.static_path/2` resolves the logical path through Volt's manifest and then passes the result through the Phoenix endpoint's `static_path/1`. With Phoenix's default configuration, the final entry URL therefore includes both hashes and `?vsn=d`.

Keep Volt hashing enabled for code-split builds. Internal static and dynamic imports use Volt's filenames directly, so those hashes provide cache busting independently of Phoenix's entry URL. `--no-hash` is intended for stable-filename builds that deliberately rely on Phoenix as their only digest layer.

## Deploy Alias

The installer generates an `assets.deploy` alias:

```elixir
"assets.deploy": ["volt.build --tailwind", "phx.digest"]
```

This builds assets with Volt content hashes, then generates the Phoenix digest manifest and compressed files for deployment. Volt is an explicit asset task rather than a Mix compiler, so a later `mix release` does not rebuild or remove this finalized output.
