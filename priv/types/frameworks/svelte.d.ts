declare module 'svelte/compiler' {
  interface CompileOptions {
    generate?: 'client' | 'server' | false
    dev?: boolean
    css?: 'external' | 'injected'
    [key: string]: unknown
  }

  interface CompileResult {
    js?: { code?: string; map?: unknown }
    css?: { code?: string; map?: unknown }
    warnings?: Array<{ code?: string; message?: string; start?: unknown; end?: unknown }>
  }

  export function compile(source: string, options: CompileOptions): CompileResult
}
