# Why Volt

Phoenix ships with esbuild for JavaScript bundling and a standalone Tailwind CLI for CSS.
These work, but they're separate binaries downloaded at build time — they can't share work,
can't coordinate HMR, and add complexity to CI/CD pipelines.

Meanwhile, the JavaScript ecosystem offers powerful dev servers like Vite, but integrating
them with Phoenix means running a separate Node.js process, configuring proxy rules, and
managing two build systems that don't know about each other.

Volt takes a different approach: compile frontend assets natively inside the BEAM using Rust NIFs.

## No External Processes

Volt doesn't shell out to Node.js, esbuild, or any external binary. JavaScript and TypeScript
are parsed, transformed, and bundled by [OXC](https://oxc.rs) through a Rust NIF. Vue
single-file components compile through [Vize](https://hex.pm/packages/vize). Tailwind CSS
uses [Oxide](https://hex.pm/packages/oxide_ex) for content scanning and
[QuickBEAM](https://hex.pm/packages/quickbeam) (QuickJS on the BEAM) for the compiler.
Everything runs in-process.

This means `mix phx.server` starts your frontend toolchain automatically. No separate
terminal, no `npm run dev`, no process supervision headaches.

## Unified Dev Server

Because Volt runs inside your Phoenix endpoint as a Plug, it serves assets on the same port
as your application. The dev server compiles files on demand with mtime caching, pushes HMR
updates over a WebSocket, and shows compilation errors as a browser overlay.

When you edit a `.heex` template, Volt detects the new Tailwind classes, incrementally
rebuilds the CSS, and hot-swaps the stylesheet — no page reload. When you edit a `.vue` or
`.tsx` file, only the changed module is re-imported via `import.meta.hot`.

## Fast Production Builds

Production builds use OXC for tree-shaking, minification, and code splitting. Tailwind CSS
compiles in parallel. A typical Phoenix app builds in under 100ms.

The output is content-hashed files with a `manifest.json`, ready for `mix phx.digest` and
CDN deployment. Source maps support hidden mode for error tracking services.

## Framework Support Without Node.js

Vue SFCs, Svelte components, and React JSX all compile without Node.js installed. Vue uses
Vize (a Rust NIF wrapping the official Vue compiler). Svelte uses QuickBEAM to run the Svelte
compiler in-process. React JSX is handled natively by OXC.

Additional frameworks and file formats can be added through the plugin system.
