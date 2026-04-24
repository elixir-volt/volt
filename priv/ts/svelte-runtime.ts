import { compile } from 'svelte/compiler'

type SvelteCompileResult = {
  js?: { code?: string; map?: unknown }
  css?: { code?: string; map?: unknown }
  warnings?: Array<{ code?: string; message?: string; start?: unknown; end?: unknown }>
}

function compileSvelte(source: string, options: Record<string, unknown> = {}) {
  const result = compile(source, {
    generate: 'client',
    dev: false,
    css: 'external',
    ...options
  }) as SvelteCompileResult

  return {
    js: result.js?.code ?? '',
    css: result.css?.code ?? '',
    jsMap: result.js?.map ?? null,
    cssMap: result.css?.map ?? null,
    warnings: (result.warnings ?? []).map((warning) => ({
      code: warning.code ?? '',
      message: warning.message ?? '',
      start: warning.start ?? null,
      end: warning.end ?? null
    }))
  }
}

globalThis.compileSvelte = compileSvelte
