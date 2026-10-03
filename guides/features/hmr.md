# Hot Module Replacement

The file watcher monitors your asset and template directories and pushes updates to the browser over a WebSocket.

## Managed session ownership

Choose one watcher owner. A watched `Volt.DevServer` starts a managed session;
`mix volt.dev` also owns a managed session and preserves its file-backed CSS sink.
Do not enable automatic Plug watching alongside a CLI watcher with different options.
To attach a Plug to a CLI-owned session, use `watch: false` and the matching identity:

```elixir
session = Volt.Dev.session_identity(root: "assets", id: :default)
plug Volt.DevServer, root: "assets", watch: false, session: session
```

Use the named profile as `id` when the CLI runs with a profile. Session identity is
independent of stylesheet URL. Put Volt's development Plug **before `Plug.Static`**
for its owned asset URLs; an earlier static plug can halt with stale generated CSS.
Configure the same Tailwind input/URL for the host and CLI. Conflicting managed
start configurations are rejected rather than merged. Requests encountering a
session disappearing during lookup return a retryable 503.

## Stylesheet dependency assets

Relative image and font URLs resolved from project stylesheets can refer to files
outside the asset root, including package assets. Volt serves these through
session-scoped `/@volt/assets/` URLs. Only files resolved by the stylesheet pipeline
are registered; the endpoint does not accept filesystem paths. Registrations end
with the session's state generation.

## What Gets Updated

| File type | Action |
| --- | --- |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.sass` | Recompile, push update over WebSocket |
| `.ex`, `.heex`, `.eex` | Incremental Tailwind rebuild, CSS hot-swap |
| `.vue` (style-only change) | CSS hot-swap, no page reload |

The browser client auto-reconnects on disconnect, reloading the page when the connection returns, and shows compilation errors as an overlay. The dev server adds the client to HTML pages the app renders, so the overlay also appears when a page's scripts fail to load.

## Server-side broadcasts

Packages that compose Volt's dev server can use `Volt.HMR` to notify connected browsers without depending on Volt's internal registry messages:

```elixir
# Re-import a stylesheet without a full reload
Volt.HMR.style_update("css/app.css")

# Ask the browser to reload the current page
Volt.HMR.full_reload("content/posts/hello.md")

# Ask open pages to check whether their HTML changed, and reload if it did
Volt.HMR.document_update("content/posts/hello.md")

# Send a custom update payload, optionally with an HMR boundary
Volt.HMR.update("src/counter.ts", [:hmr], boundary: "/assets/counter.ts")

# Show the browser error overlay, then hide it once the file is fixed
Volt.HMR.error("content/posts/hello.md", "Invalid frontmatter")
Volt.HMR.clear_error("content/posts/hello.md")
```

Errors can be messages, exceptions, or `OXC.Diagnostic` maps with a location, which the overlay shows with a source frame. They stay current until cleared, so browsers that connect later see them too.

Use this when an external package owns additional dependency graphs, such as pages, layouts, or content collections, while Volt serves the asset graph.

`Volt.HMR.invalidate_file/1` evicts Volt's dev compilation state for a source file and marks its module-graph nodes invalidated without broadcasting. Use it before sending your own update when an external package knows a file's compiled output is stale.

## Watching extra reload directories

`Volt.Watcher` can watch directories of templates and content outside the asset root. When a file there changes, open pages check whether their HTML changed and reload only if it did:

```elixir
Volt.Watcher.start_link(
  root: "assets",
  reload_dirs: ["content", "layouts"]
)
```

The same option is available from config/CLI:

```elixir
config :volt, :server,
  reload_dirs: ["content", "layouts"]
```

```bash
mix volt.dev --reload-dir content --reload-dir layouts
```

This is intentionally generic: Volt does not parse those files or assign site semantics to them.

### Reloading only the pages that changed

A template or content file may affect any page, or none, and Volt does not know which. Each HTML page the dev server adds its client to carries an entity tag of the HTML it was rendered with. On a change, the client requests its page again with `If-None-Match`; the server renders it, answers `304 Not Modified` when the HTML is the same, and the page stays as it is. Any other answer reloads the page.

So editing one blog post reloads the tab showing that post and leaves the others alone, and saving a file without changing what a page renders reloads nothing. Pages whose HTML differs on every render, such as those embedding a CSRF token, reload on every change as before.

A server that adds the dev client to its pages itself opts in by following `Volt.HMR.Document`.

## Ignoring watcher paths

Exclude generated or otherwise irrelevant files before Volt schedules compilation or HMR work:

```elixir
config :volt, :server,
  watch_ignored: ["**/.generated/**", "vendor/cache/**"]
```

Patterns use GlobEx syntax and are resolved relative to each watched root. The same option is available from the CLI:

```bash
mix volt.dev --watch-ignore "**/.generated/**"
```

Volt ignores `.git`, `node_modules`, `test-results`, `_build`, and `deps` directories by default. Ignoring a path affects file watching only; it does not prevent the dev server from serving an explicitly requested module.

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
