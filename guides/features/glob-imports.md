# Glob Imports

`import.meta.glob()` resolves glob patterns at build time into a map of file paths to modules.

## Lazy (Default)

```typescript
const modules = import.meta.glob('./pages/*.ts')
```

Transforms into:

```typescript
const modules = {
  './pages/home.ts': () => import('./pages/home.ts'),
  './pages/about.ts': () => import('./pages/about.ts'),
}
```

Each entry is a function that returns a dynamic import — the module is only loaded when called.

## Eager

```typescript
const modules = import.meta.glob('./pages/*.ts', { eager: true })
```

Transforms into:

```typescript
import * as __glob_0 from './pages/about.ts'
import * as __glob_1 from './pages/home.ts'
const modules = {
  './pages/about.ts': __glob_0,
  './pages/home.ts': __glob_1,
}
```

All modules are imported statically and available immediately.
