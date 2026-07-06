declare module '@babel/standalone' {
  export interface BabelTransformResult {
    code?: string
    map?: unknown
  }

  export function registerPreset(name: string, preset: unknown): void
  export function transform(source: string, options: Record<string, unknown>): BabelTransformResult
}
