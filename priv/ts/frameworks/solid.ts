interface BabelTransformResult {
  code?: string
  map?: unknown
}

interface BabelStandalone {
  registerPreset(name: string, preset: unknown): void
  transform(source: string, options: Record<string, unknown>): BabelTransformResult
}

interface CompileOptions {
  filename?: string
  typescript?: boolean
  sourcemap?: boolean
  solidOptions?: Record<string, unknown>
  typescriptOptions?: Record<string, unknown>
}

interface CompileResult {
  code: string
  map: unknown | null
}

let compiler: BabelStandalone | null = null

async function loadCompiler(): Promise<BabelStandalone> {
  if (compiler) return compiler

  const Babel = (await import('@babel/standalone')) as unknown as BabelStandalone
  const solidPreset = await import('babel-preset-solid')
  Babel.registerPreset('solid', (solidPreset as { default?: unknown }).default ?? solidPreset)
  compiler = Babel
  return compiler
}

async function compileSolid(
  source: string,
  input: CompileOptions | string = {}
): Promise<CompileResult> {
  const Babel = await loadCompiler()
  const options = typeof input === 'string' ? (JSON.parse(input) as CompileOptions) : input
  const filename = options.filename ?? 'component.tsx'
  const typescript = options.typescript ?? /\.[cm]?tsx?$/.test(filename)

  const presets: unknown[] = []

  if (typescript) {
    presets.push([
      'typescript',
      {
        isTSX: filename.endsWith('.tsx'),
        allExtensions: true,
        allowDeclareFields: true,
        ...options.typescriptOptions
      }
    ])
  }

  presets.push(['solid', options.solidOptions])

  const result = Babel.transform(source, {
    filename,
    sourceMaps: options.sourcemap ?? true,
    presets
  })

  return {
    code: result?.code ?? '',
    map: result?.map ?? null
  }
}

;(globalThis as typeof globalThis & { compileSolid: typeof compileSolid }).compileSolid =
  compileSolid
