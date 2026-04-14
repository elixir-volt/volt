type BeamModuleSpec = {
  path: string
  base: string
  code: string
  format: 'cjs' | 'json'
}

type TailwindCompiler = {
  compile: (
    css: string,
    options: {
      base: string
      from: string
      loadStylesheet: (id: string, base?: string) => Promise<{ base: string; content: string }>
      loadModule: (id: string, base?: string, type?: string) => Promise<{ module: unknown; base: string }>
    }
  ) => Promise<{ build: (candidates: string[]) => string }>
  Features?: unknown
}

declare const Beam: {
  callSync: (name: string, ...args: unknown[]) => any
}

declare const TAILWIND_ROOT: string

declare const TAILWIND_DEFAULT_BASE: string

const fs = (globalThis as typeof globalThis & {
  fs: { readFileSync: (path: string, encoding: string) => string }
}).fs

const path = (globalThis as typeof globalThis & {
  path: {
    join: (...parts: string[]) => string
    dirname: (path: string) => string
  }
}).path

const nodeProcess = (globalThis as typeof globalThis & {
  process?: { env?: Record<string, string> }
}).process

if (nodeProcess?.env) {
  nodeProcess.env.NODE_ENV ??= 'production'
}

const themeCssPath = path.join(TAILWIND_ROOT, 'theme.css')
const preflightCssPath = path.join(TAILWIND_ROOT, 'preflight.css')
const utilitiesCssPath = path.join(TAILWIND_ROOT, 'utilities.css')
const tailwindRuntimeSpec = Beam.callSync(
  'tailwind.load_module',
  path.join(TAILWIND_ROOT, 'dist', 'lib.js'),
  TAILWIND_ROOT,
  'require'
) as BeamModuleSpec
const tailwindExports = requireResolvedModule(tailwindRuntimeSpec, new Map()) as TailwindCompiler

async function compileTailwindCss(
  inputCss: string | null,
  candidates: string[] | null,
  base: string | null
) {
  const moduleCache = new Map<string, { exports: unknown }>()
  const rootBase = normalizeBase(base, TAILWIND_DEFAULT_BASE)
  const css = inputCss == null ? '@import "tailwindcss";' : inputCss

  const compiler = await tailwindExports.compile(css, {
    base: rootBase,
    from: 'app.css',
    loadStylesheet: async (id, currentBase) => {
      if (id === 'tailwindcss') {
        return {
          base: rootBase,
          content:
            '@import "tailwindcss/theme.css" layer(theme);\n@import "tailwindcss/preflight.css" layer(base);\n@import "tailwindcss/utilities.css" layer(utilities);',
        }
      }

      if (id === 'tailwindcss/theme.css') {
        return {
          base: rootBase,
          content: tailwindExports.Features ? fs.readFileSync(themeCssPath, 'utf8') : '',
        }
      }

      if (id === 'tailwindcss/preflight.css') {
        return { base: rootBase, content: fs.readFileSync(preflightCssPath, 'utf8') }
      }

      if (id === 'tailwindcss/utilities.css') {
        return { base: rootBase, content: fs.readFileSync(utilitiesCssPath, 'utf8') }
      }

      return Beam.callSync('tailwind.load_stylesheet', id, normalizeBase(currentBase, rootBase))
    },
    loadModule: async (id, currentBase, type) => {
      const spec = Beam.callSync(
        'tailwind.load_module',
        id,
        normalizeBase(currentBase, rootBase),
        type ?? 'plugin'
      ) as BeamModuleSpec

      return { module: requireResolvedModule(spec, moduleCache), base: spec.base }
    },
  })

  return compiler.build(candidates ?? [])
}

function normalizeBase(base: string | null | undefined, fallbackBase: string) {
  return base == null || base === '' ? fallbackBase : base
}

function requireResolvedModule(
  spec: BeamModuleSpec,
  moduleCache: Map<string, { exports: unknown }>
) {
  if (spec.format === 'json') {
    if (!moduleCache.has(spec.path)) {
      moduleCache.set(spec.path, { exports: JSON.parse(spec.code) })
    }

    return moduleCache.get(spec.path)!.exports
  }

  return loadCommonJSModule(spec.path, moduleCache, spec.code, spec.base)
}

function loadCommonJSModule(
  modulePath: string,
  moduleCache: Map<string, { exports: unknown }>,
  code?: string,
  moduleBase?: string
) {
  const resolvedPath = modulePath

  if (moduleCache.has(resolvedPath)) {
    return moduleCache.get(resolvedPath)!.exports
  }

  const loaded = { exports: {} as unknown }
  moduleCache.set(resolvedPath, loaded)

  const source = code ?? ''
  const dirname = moduleBase ?? path.dirname(resolvedPath)

  const localRequire = (id: string) => {
    const childSpec = Beam.callSync('tailwind.load_module', id, dirname, 'require') as BeamModuleSpec
    return requireResolvedModule(childSpec, moduleCache)
  }

  try {
    if (source === '') {
      throw new Error(`Missing bundled source for ${resolvedPath}`)
    }

    const factory = new Function('module', 'exports', 'require', '__filename', '__dirname', source)
    factory(loaded, loaded.exports, localRequire, resolvedPath, dirname)
    return loaded.exports
  } catch (error) {
    moduleCache.delete(resolvedPath)
    throw error
  }
}

globalThis.compileTailwindCss = compileTailwindCss
