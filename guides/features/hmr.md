# Hot Module Replacement

The file watcher monitors your asset and template directories and pushes updates to the browser over a WebSocket.

## What Gets Updated

| File type | Action |
| --- | --- |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.vue`, `.svelte`, `.css` | Recompile, push update over WebSocket |
| `.ex`, `.heex`, `.eex` | Incremental Tailwind rebuild, CSS hot-swap |
| `.vue` (style-only change) | CSS hot-swap, no page reload |

The browser client auto-reconnects on disconnect and shows compilation errors as an overlay.

## Server-side broadcasts

Packages that compose Volt's dev server can use `Volt.HMR` to notify connected browsers without depending on Volt's internal registry messages:

```elixir
# Re-import a stylesheet without a full reload
Volt.HMR.style_update("css/app.css")

# Ask the browser to reload the current page
Volt.HMR.full_reload("content/posts/hello.md")

# Send a custom update payload, optionally with an HMR boundary
Volt.HMR.update("src/counter.ts", [:hmr], boundary: "/assets/counter.ts")

# Show the browser error overlay
Volt.HMR.error("content/posts/hello.md", "Invalid frontmatter")
```

Use this when an external package owns additional dependency graphs, such as pages, layouts, or content collections, while Volt serves the asset graph.

## `import.meta.hot`

Each module served in dev mode includes an `import.meta.hot` object for granular HMR:

```javascript
let timer: ReturnType<typeof setInterval>

export function startClock(el: HTMLElement) {
  const update = () => { el.textContent = new Date().toLocaleTimeString() }
  update()
  timer = setInterval(update, 1000)
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => clearInterval(timer))
  import.meta.hot.accept()
}
```

When a file changes, Volt walks the dev module graph upward to find the nearest module with `import.meta.hot.accept()`. Only that module is re-imported — no full page reload. If no boundary is found, the client falls back to `location.reload()`.

## API

- `accept()` — mark this module as an HMR boundary
- `accept(deps, cb)` — accept updates for specific dependencies
- `dispose(cb)` — clean up before the module is replaced (receives `data` for state transfer)
- `data` — persistent object that survives HMR updates (populated by `dispose`)
- `invalidate()` — force a full page reload
