// ── HMR Context (import.meta.hot) ──────────────────────────────

interface HotCallback {
  deps: string[]
  fn: (modules: unknown[]) => void
}

interface HotModule {
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
          mod.callbacks.push({ deps: [ownerPath], fn: deps as (m: unknown[]) => void })
        }
      } else if (typeof deps === 'string') {
        mod.callbacks.push({
          deps: [deps],
          fn: callback as (m: unknown[]) => void
        })
      } else if (Array.isArray(deps)) {
        mod.callbacks.push({
          deps: deps as string[],
          fn: callback as (m: unknown[]) => void
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
      // reserved for future events
    }
  }
}

// ── WebSocket connection ───────────────────────────────────────

const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'

let ws: WebSocket | undefined
let reconnectTimer: ReturnType<typeof setTimeout> | undefined

function connect() {
  ws = new WebSocket(`${proto}//${location.host}/@volt/ws`)

  ws.onopen = () => {
    console.log('[Volt] HMR connected')

    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = undefined
    }
  }

  ws.onmessage = (event) => {
    const { type, payload } = JSON.parse(event.data) as {
      type: string
      payload: Record<string, unknown>
    }

    switch (type) {
      case 'update':
        handleUpdate(payload as { path: string; changes: string[]; timestamp?: number })
        break
      case 'error':
        showOverlay(payload.reason)
        break
      case 'full-reload':
        location.reload()
        break
      default:
        location.reload()
        break
    }
  }

  ws.onclose = () => {
    console.log('[Volt] Disconnected. Reconnecting...')
    reconnectTimer = setTimeout(connect, 1000)
  }
}

// ── Update handling ────────────────────────────────────────────

async function handleUpdate(payload: {
  path: string
  changes: string[]
  boundary?: string
  timestamp?: number
}) {
  const { path, changes, boundary, timestamp } = payload

  if (changes.length === 1 && changes[0] === 'style') {
    updateStyles(path)
    return
  }

  if (changes.includes('hmr') && boundary) {
    await applyHMRUpdate(boundary, timestamp ?? Date.now())
    return
  }

  location.reload()
}

async function applyHMRUpdate(boundary: string, timestamp: number) {
  // Find the hot module by matching the boundary path suffix against registered URLs.
  // The server sends a relative path (e.g. "App.tsx") while modules are registered
  // with full URL paths (e.g. "/assets/App.tsx").
  let modUrl = boundary
  let mod = hotModules.get(boundary)

  if (!mod) {
    for (const [url, m] of hotModules) {
      if (url.endsWith('/' + boundary) || url === boundary) {
        mod = m
        modUrl = url
        break
      }
    }
  }

  if (!mod) {
    location.reload()
    return
  }

  const savedCallbacks = [...mod.callbacks]

  const newData: Record<string, unknown> = {}
  for (const cb of mod.disposeCallbacks) {
    cb(newData)
  }
  dataMap.set(modUrl, newData)

  try {
    const url = `${modUrl}${modUrl.includes('?') ? '&' : '?'}t=${timestamp}`
    const newModule = await import(/* @vite-ignore */ url)

    for (const cb of savedCallbacks) {
      if (cb.fn) {
        cb.fn([newModule])
      }
    }

    console.log(`[Volt] HMR update: ${modUrl}`)
  } catch (err) {
    console.error(`[Volt] HMR update failed for ${modUrl}`, err)
    location.reload()
  }
}

function updateStyles(path: string) {
  const links = document.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]')
  let updated = false

  for (const link of links) {
    const href = link.getAttribute('href')

    if (href && (href.includes(path) || path.endsWith('.css'))) {
      const url = new URL(link.href)
      url.searchParams.set('t', Date.now().toString())
      link.href = url.toString()
      updated = true
    }
  }

  if (!updated) {
    location.reload()
  }
}

function showOverlay(reason: unknown) {
  let overlay = document.getElementById('volt-error-overlay')

  if (!overlay) {
    overlay = document.createElement('div')
    overlay.id = 'volt-error-overlay'
    overlay.style.cssText =
      'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto;cursor:pointer'
    overlay.onclick = () => overlay?.remove()
    document.body.appendChild(overlay)
  }

  const message = typeof reason === 'string' ? reason : JSON.stringify(reason, null, 2)
  overlay.textContent = `[Volt] Build error:\n\n${message}`
}

connect()
