interface ImportMeta {
  hot?: {
    data?: unknown
    accept(callback?: (module?: unknown) => void): void
    dispose(callback: (data?: unknown) => void): void
  }
}

interface Window {
  __voltConsoleForwarderInstalled?: boolean
}
