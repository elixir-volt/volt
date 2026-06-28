# Static Assets

Images, fonts, SVGs, media, WebAssembly, PDFs, and text files are handled automatically when referenced from JavaScript or CSS. Emitted assets are also written to the production manifest so server-rendered templates can resolve their hashed paths with `Volt.static_path/2`.

Volt follows Vite-style asset import semantics in both dev and production:

- JavaScript imports become modules that export a string.
- `new URL("./asset.ext", import.meta.url)` participates in the production graph.
- Production builds copy referenced files with content-hashed names and rewrite JavaScript URLs to `/assets/...`.

CSS is parsed and bundled by LightningCSS through Vize. Production builds also parse CSS with Vize's LightningCSS-backed AST API and rewrite relative `url(...)` asset references to content-hashed `/assets/...` URLs. In dev, CSS imports are rewritten to dev-server asset URLs so injected styles resolve from the source tree.

## Default imports

Small files under the inline limit are inlined as base64 data URIs:

```javascript
import icon from './icon.svg'
// icon = "data:image/svg+xml;base64,..."
```

Larger files are copied to the output directory and exported as public URLs:

```javascript
import photo from './photo.jpg'
// photo = "/assets/photo-a1b2c3d4.jpg"
```

The default inline limit is 4 KB.

## Query modes

Use query suffixes when you need a specific representation:

```javascript
import source from './message.txt?raw'
import url from './logo.svg?url'
import inlineIcon from './icon.svg?inline'
import fileUrl from './small-icon.svg?no-inline'
```

| Query | Result |
| --- | --- |
| `?raw` | exports file contents as a string |
| `?url` | exports a public URL |
| `?inline` | exports a data URI even when the file is larger than the inline limit |
| `?no-inline` | exports a public URL even when the file is small |

## `new URL(..., import.meta.url)`

Relative asset URL constructors are rewritten during production builds:

```javascript
const logo = new URL('./logo.svg', import.meta.url).href
```

The referenced file is copied with a content hash and the bundled JavaScript points at the emitted `/assets/...` URL.

Only relative specifiers that resolve to known asset extensions are rewritten. Remote URLs, absolute URLs, and non-asset modules are left unchanged.

## CSS URLs

Production builds rewrite relative CSS asset URLs through the same hashed asset pipeline as JavaScript references:

```css
.logo {
  background-image: url('./images/logo.svg');
}
```

The referenced file is copied to the output directory and the final CSS points at `/assets/logo-a1b2c3d4.svg`. The emitted asset filename is included in the CSS manifest entry's `assets` list, and the original asset path gets its own manifest entry for `Volt.static_path/2`. This is parser-backed: Volt parses CSS with Vize's LightningCSS AST API and rewrites URL nodes, including nested usages such as `image-set(url(...))`.

Root-absolute URLs (`/images/logo.svg`), external URLs, data URLs, missing files, and unknown extensions are left unchanged. Use those forms for assets that should stay at Phoenix/static or public-directory paths.

## Source asset resolution

Use `Volt.Assets.resolve/2` when another Elixir layer needs to resolve an asset source file with Volt's alias semantics, without importing it into the JavaScript build graph:

```elixir
Volt.Assets.resolve!("@/icons/logo.svg",
  importer: "/app/pages/index.astral",
  root: "/app/assets",
  aliases: Volt.Config.build().aliases,
  extensions: [".svg"]
)
```

The resolver supports explicit aliases, `tsconfig.json` paths merged by `Volt.Config`, relative specifiers from `:importer`, root-relative specifiers such as `/icons/logo.svg`, and plain paths under `:root`. It intentionally resolves only files; package imports, externals, and plugin virtual modules remain build/dev-server concerns.

## Asset URL prefix

Production JavaScript and CSS asset references use `/assets` by default, matching Phoenix's conventional `priv/static/assets` mount. Configure `asset_url_prefix` when assets are served from a subpath or CDN:

```elixir
config :volt, asset_url_prefix: "/my-app/assets"
```

This only changes URLs emitted into built JavaScript and CSS. It does not change `outdir`, the dev-server prefix, or Phoenix endpoint/static URL configuration.

## Phoenix static files and optional public directory

In Phoenix apps, stable root files usually belong in `priv/static` and are served by Phoenix through `Plug.Static`:

```text
priv/static/favicon.svg -> /favicon.svg
priv/static/robots.txt  -> /robots.txt
```

Volt's asset pipeline is for files referenced by JavaScript or CSS when you want dependency tracking, hashing, and URL rewriting. Once an asset is part of the Volt graph, templates can reference it by its source-relative path:

```heex
<img src={Volt.static_path(MyAppWeb.Endpoint, "/assets/images/logo.svg")} />
```

Files that are only used from templates and are not imported by JavaScript or CSS should stay in `priv/static` and use Phoenix's `~p` or `static_path` helpers.

For Vite migration compatibility, Volt also supports an optional `public_dir`. It is disabled by default. When enabled, files in that directory are served and copied without transformation:

```elixir
config :volt,
  public_dir: "public"
```

```text
public/favicon.svg -> /favicon.svg
```

Public directory files are not hashed and are not processed by import query modes. Prefer module imports for assets referenced by JavaScript when you want hashing and dependency tracking.

## Supported formats

Images (`.svg`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.avif`, `.ico`), fonts (`.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`), media (`.mp4`, `.webm`, `.ogg`, `.mp3`, `.wav`), and other formats (`.pdf`, `.wasm`, `.txt`).
