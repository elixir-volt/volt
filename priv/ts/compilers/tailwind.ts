type BeamModuleSpec = {
  path: string
  base: string
  code: string
  dependencies: string[]
  format: 'cjs' | 'json'
}

type Source = { base: string; pattern: string; negated: boolean }

type TailwindCompiler = {
  compile: (
    css: string,
    options: {
      base: string
      from: string
      loadStylesheet: (
        id: string,
        base?: string
      ) => Promise<{ path: string; base: string; content: string }>
      loadModule: (
        id: string,
        base?: string,
        type?: string
      ) => Promise<{ path: string; module: unknown; base: string }>
    }
  ) => Promise<{
    build: (candidates: string[]) => string
    root: null | 'none' | { base: string; pattern: string }
    sources: Source[]
  }>
  Features?: unknown
}

declare const Beam: {
  callSync: (name: string, ...args: unknown[]) => unknown
}

declare const TAILWIND_ROOT: string

declare const TAILWIND_DEFAULT_BASE: string

const fs = (
  globalThis as typeof globalThis & {
    fs: { readFileSync: (path: string, encoding: string) => string }
  }
).fs

const path = (
  globalThis as typeof globalThis & {
    path: {
      join: (...parts: string[]) => string
      dirname: (path: string) => string
    }
  }
).path

const nodeProcess = (
  globalThis as typeof globalThis & {
    process?: { env?: Record<string, string> }
  }
).process

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

const compilerContexts = new Map<number, Awaited<ReturnType<TailwindCompiler['compile']>>>()
let nextCompilerContext = 0

async function compileTailwindCss(
  inputCss: string | null,
  candidates: string[] | null,
  base: string | null,
  scan: { base: string; sources: Source[] } | null = null,
  metadata = false,
  retain = false
) {
  const dependencies = new Set<string>()
  const moduleCache = new Map<string, { exports: unknown }>()
  const rootBase = normalizeBase(base, TAILWIND_DEFAULT_BASE)
  const css = inputCss === null ? '@import "tailwindcss";' : inputCss

  let compiler: Awaited<ReturnType<TailwindCompiler['compile']>>
  try {
    compiler = await tailwindExports.compile(css, {
      base: rootBase,
      from: 'app.css',
      loadStylesheet: async (id, currentBase) => {
        if (id === 'tailwindcss') {
          return {
            path: path.join(TAILWIND_ROOT, 'index.css'),
            base: rootBase,
            content:
              '@import "tailwindcss/theme.css" layer(theme);\n@import "tailwindcss/preflight.css" layer(base);\n@import "tailwindcss/utilities.css" layer(utilities);'
          }
        }

        if (id === 'tailwindcss/theme.css') {
          return {
            path: themeCssPath,
            base: rootBase,
            content: tailwindExports.Features ? fs.readFileSync(themeCssPath, 'utf8') : ''
          }
        }

        if (id === 'tailwindcss/preflight.css') {
          return {
            path: preflightCssPath,
            base: rootBase,
            content: fs.readFileSync(preflightCssPath, 'utf8')
          }
        }

        if (id === 'tailwindcss/utilities.css') {
          return {
            path: utilitiesCssPath,
            base: rootBase,
            content: fs.readFileSync(utilitiesCssPath, 'utf8')
          }
        }

        const stylesheet = Beam.callSync(
          'tailwind.load_stylesheet',
          id,
          normalizeBase(currentBase, rootBase),
          rootBase
        ) as
          | { path: string; base: string; content: string }
          | { error: string; candidates: string[] }
        if ('error' in stylesheet) {
          for (const candidate of stylesheet.candidates) dependencies.add(candidate)
          throw new Error(stylesheet.error)
        }
        dependencies.add(stylesheet.path)
        return stylesheet
      },
      loadModule: async (id, currentBase, type) => {
        const spec = Beam.callSync(
          'tailwind.load_module',
          id,
          normalizeBase(currentBase, rootBase),
          type ?? 'plugin'
        ) as BeamModuleSpec | { error: string; candidates: string[] }

        if ('error' in spec) {
          for (const candidate of spec.candidates) dependencies.add(candidate)
          throw new Error(spec.error)
        }
        for (const dependency of spec.dependencies) dependencies.add(dependency)
        const mod = requireResolvedModule(spec, moduleCache)
        return { path: spec.path, module: unwrapModule(mod), base: spec.base }
      }
    })
  } catch (error) {
    if (retain) return { error: String(error), dependencies: [...dependencies].sort() }
    throw error
  }

  if (scan) {
    let automatic: Source[] = []
    if (compiler.root === null) {
      automatic = [{ base: scan.base, pattern: '**/*', negated: false }]
    } else if (compiler.root !== 'none') {
      automatic = [{ ...compiler.root, negated: false }]
    }
    candidates = Beam.callSync('tailwind.scan', [
      ...automatic,
      ...scan.sources,
      ...compiler.sources
    ]) as string[]
  }
  if (retain) {
    const id = ++nextCompilerContext
    compilerContexts.set(id, compiler)
    return {
      id,
      code: '',
      dependencies: [...dependencies].sort(),
      sources: compiler.sources,
      root: compiler.root
    }
  }
  const code = compiler.build(candidates ?? [])
  return metadata
    ? {
        code,
        dependencies: [...dependencies].sort(),
        sources: compiler.sources,
        root: compiler.root
      }
    : code
}

function normalizeBase(base: string | null | undefined, fallbackBase: string) {
  return base === null || base === undefined || base === '' ? fallbackBase : base
}

function unwrapModule(mod: unknown): unknown {
  if (mod && typeof mod === 'object' && '__esModule' in mod && 'default' in mod) {
    return (mod as Record<string, unknown>).default
  }
  return mod
}

function requireResolvedModule(
  spec: BeamModuleSpec,
  moduleCache: Map<string, { exports: unknown }>
) {
  if (spec.format === 'json') {
    if (!moduleCache.has(spec.path)) {
      moduleCache.set(spec.path, { exports: JSON.parse(spec.code) })
    }

    return moduleCache.get(spec.path)?.exports
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
    return moduleCache.get(resolvedPath)?.exports
  }

  const loaded = { exports: {} as unknown }
  moduleCache.set(resolvedPath, loaded)

  const source = code ?? ''
  const dirname = moduleBase ?? path.dirname(resolvedPath)

  const localRequire = (id: string) => {
    const builtin = (globalThis as Record<string, unknown>)[id]
    if (builtin !== undefined) {
      return builtin
    }

    const childSpec = Beam.callSync(
      'tailwind.load_module',
      id,
      dirname,
      'require'
    ) as BeamModuleSpec
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

async function prepareTailwindContext(css: string | null, base: string) {
  return compileTailwindCss(css, [], base, null, true, true)
}
function buildTailwindContext(id: number, candidates: string[]) {
  const compiler = compilerContexts.get(id)
  if (!compiler) throw new Error('Unknown Tailwind compiler context')
  return compiler.build(candidates)
}
function releaseTailwindContext(id: number) {
  return compilerContexts.delete(id)
}

globalThis.prepareTailwindContext = prepareTailwindContext
globalThis.buildTailwindContext = buildTailwindContext
globalThis.releaseTailwindContext = releaseTailwindContext

globalThis.compileTailwindCss = compileTailwindCss
