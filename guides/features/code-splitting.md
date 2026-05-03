# Code Splitting

Dynamic imports are automatically split into separate chunks:

```javascript
import { setup } from './core'

const admin = await import('./admin')
```

Produces:

```text
app-5e6f7a8b.js        42 KB   (entry)
app-admin-c3d4e5f6.js  86 KB   (async)
manifest.json           3 entries
```

Shared modules between chunks are extracted into common chunks to avoid duplication.

Disable with `code_splitting: false` in config or `--no-code-splitting` flag.

## Manual Chunks

Control chunk boundaries explicitly:

```elixir
config :volt,
  chunks: %{
    "vendor" => ["vue", "vue-router", "pinia"],
    "ui" => ["assets/src/components"]
  }
```

Bare specifiers match package names in `node_modules`. Path patterns match by directory prefix. Manual chunks work alongside automatic dynamic-import splitting.
