# Production Builds

```bash
mix volt.build
```

```
Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB
  manifest.json  2 entries
Built in 15ms
```

Reads configuration from `config :volt`. CLI flags override config values.

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

For code-split builds, `Volt.Preload.tags/2` generates `<link rel="modulepreload">` tags from the build manifest to preload async chunks:

```heex
<%= Volt.Preload.tags("priv/static/assets/js/manifest.json", "/assets/js") %>
```

## Deploy Alias

The installer generates an `assets.deploy` alias:

```elixir
"assets.deploy": ["volt.build --tailwind", "phx.digest"]
```

This builds assets with content hashes, then generates the Phoenix digest manifest for CDN deployment.
