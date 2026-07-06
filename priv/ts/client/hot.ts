export interface HotCallback {
  deps: string[]
  kind: 'self' | 'single' | 'multi'
  fn: (module: unknown) => void
}

export interface HotModule {
  id: string
  callbacks: HotCallback[]
  disposeCallbacks: ((data: Record<string, unknown>) => void)[]
  data: Record<string, unknown>
  acceptSelf: boolean
}

const hotModules = new Map<string, HotModule>()
const dataMap = new Map<string, Record<string, unknown>>()

export function createHotContext(ownerPath: string) {
  const existing = hotModules.get(ownerPath)
  if (existing) {
    existing.callbacks = []
    existing.disposeCallbacks = []
    existing.acceptSelf = false
    existing.data = dataMap.get(ownerPath) ?? {}
  }

  const mod: HotModule = existing ?? {
    id: ownerPath,
    callbacks: [],
    disposeCallbacks: [],
    data: dataMap.get(ownerPath) ?? {},
    acceptSelf: false
  }

  hotModules.set(ownerPath, mod)

  return {
    get data() {
      return mod.data
    },

    accept(deps?: unknown, callback?: unknown) {
      if (typeof deps === 'function' || deps === undefined) {
        mod.acceptSelf = true
        if (typeof deps === 'function') {
          mod.callbacks.push({ deps: [ownerPath], kind: 'self', fn: deps as (m: unknown) => void })
        }
      } else if (typeof deps === 'string') {
        mod.callbacks.push({
          deps: [deps],
          kind: 'single',
          fn: callback as (m: unknown) => void
        })
      } else if (Array.isArray(deps)) {
        mod.callbacks.push({
          deps: deps as string[],
          kind: 'multi',
          fn: callback as (m: unknown) => void
        })
      }
    },

    dispose(cb: (data: Record<string, unknown>) => void) {
      mod.disposeCallbacks.push(cb)
    },

    invalidate() {
      location.reload()
    },

    on(_event: string, _cb: (...args: unknown[]) => void) {
      return undefined
    }
  }
}

export function findHotModule(path: string): [string, HotModule] | undefined {
  const exact = hotModules.get(path)

  if (exact) {
    return [path, exact]
  }

  for (const entry of hotModules) {
    const [url] = entry
    if (url.endsWith('/' + path) || url === path) {
      return entry
    }
  }
}

export function hotModuleFor(url: string) {
  return hotModules.get(url)
}

export function preserveHotData(url: string, data: Record<string, unknown>) {
  dataMap.set(url, data)
}
