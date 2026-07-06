# Glob Imports

`import.meta.glob()` resolves file patterns at transform time into a map of module paths to import functions or modules. Volt supports the common Vite forms in ordinary source files and in JavaScript emitted by framework plugins such as Vue and Svelte.

## Lazy imports

```javascript
const modules = import.meta.glob('./pages/*.ts')
```

Transforms into a map whose values are dynamic import functions:

```javascript
const modules = {
  './pages/about.ts': () => import('./pages/about.ts'),
  './pages/home.ts': () => import('./pages/home.ts'),
}
```

Each module is loaded only when its function is called.

## Eager imports

```javascript
const modules = import.meta.glob('./pages/*.ts', { eager: true })
```

Transforms into static imports:

```javascript
import * as __glob_0 from './pages/about.ts'
import * as __glob_1 from './pages/home.ts'

const modules = {
  './pages/about.ts': __glob_0,
  './pages/home.ts': __glob_1,
}
```

Use eager imports when the files must be included in the initial bundle or when you need synchronous access to the modules.

## Multiple and negative patterns

Pass an array to include multiple patterns. Prefix a pattern with `!` to exclude matches:

```javascript
const pages = import.meta.glob([
  './pages/**/*.ts',
  './admin/**/*.ts',
  '!./pages/**/__tests__/*.ts',
])
```

## Named imports

Use the `import` option to select one export from every module:

```javascript
const names = import.meta.glob('./pages/*.ts', { import: 'name' })
```

Lazy named imports load the module and resolve to the selected export. Eager named imports generate named static imports:

```javascript
const names = import.meta.glob('./pages/*.ts', {
  eager: true,
  import: 'name',
})
```

Use `import: 'default'` for default exports and `import: '*'` to keep namespace modules.

## Query option

The `query` option appends query parameters to each generated import. This is useful with asset query modes:

```javascript
const rawFiles = import.meta.glob('./content/*.md', {
  query: '?raw',
})
```

Object query values are encoded as URL parameters:

```javascript
const modules = import.meta.glob('./icons/*.svg', {
  query: { url: true },
})
```

## Base option

`base` changes the keys in the returned object while imports still point at the matched files:

```javascript
const pages = import.meta.glob('./pages/*.ts', {
  base: './pages',
})

// keys look like "./home.ts" instead of "./pages/home.ts"
```

## TypeScript generic syntax

Type-only generic arguments are accepted and ignored at runtime:

```javascript
const modules = import.meta.glob<PageModule>('./pages/*.ts')
```

## HMR invalidation

In development, Volt tracks glob patterns in the HMR glob graph. When a file matching an `import.meta.glob()` pattern is added, changed, or removed, the module that owns the glob is invalidated so the next import sees the updated file list.

This is especially useful for file-based routing and component auto-discovery.

## Dynamic import variables

Volt rewrites simple relative template-literal dynamic imports through `import.meta.glob()` so production builds can include the possible modules:

```javascript
const page = await import(`./pages/${name}.ts`)
```

This is intended for relative paths with a static prefix and suffix. Static query suffixes are preserved through glob query options:

```javascript
const raw = await import(`./content/${slug}.md?raw`)
```

Bare package imports and absolute URLs are left untouched.
