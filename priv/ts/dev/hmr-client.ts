// ── HMR Context (import.meta.hot) ──────────────────────────────

interface HotCallback {
  deps: string[]
  kind: 'self' | 'single' | 'multi'
  fn: (module: unknown) => void
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
      // reserved for future events
    }
  }
}

// ── WebSocket connection ───────────────────────────────────────

const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'

let ws: WebSocket | undefined
let reconnectTimer: ReturnType<typeof setTimeout> | undefined
let heartbeatTimer: ReturnType<typeof setInterval> | undefined
let lastPongAt = 0
let reconnectAttempts = 0

// Bound at serve time from the server's `hmr_timeout` (half of it) so the
// heartbeat always lands inside Bandit's websocket `read_timeout` window.
// The value is injected by the dev server when serving this module.
const configuredHeartbeat = (globalThis as Record<string, unknown>).__VOLT_HEARTBEAT__
const HEARTBEAT_INTERVAL = typeof configuredHeartbeat === 'number' ? configuredHeartbeat : 25_000
const PONG_GRACE = HEARTBEAT_INTERVAL * 2

// Exponential reconnect backoff with jitter to avoid a thundering herd of
// browser tabs reconnecting at the same instant when the dev server restarts.
const RECONNECT_BASE = 1_000
const RECONNECT_MAX = 30_000

function connect() {
  ws = new WebSocket(`${proto}//${location.host}/@volt/ws`)

  ws.onopen = () => {
    console.log('[Volt] HMR connected')

    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = undefined
    }

    // Successful (re)connection resets the backoff.
    reconnectAttempts = 0
    lastPongAt = Date.now()

    // Send periodic pings so the server's websocket read_timeout does not
    // close an otherwise idle connection between file changes. The server
    // replies with a `pong`; if we stop receiving pongs we assume the link
    // is half-open and force a reconnect.
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer)
    }

    heartbeatTimer = setInterval(() => {
      if (!ws || ws.readyState !== WebSocket.OPEN) return

      if (Date.now() - lastPongAt > PONG_GRACE) {
        ws.close()
        return
      }

      ws.send(JSON.stringify({ type: 'ping' }))
    }, HEARTBEAT_INTERVAL)
  }

  ws.onmessage = (event) => {
    const { type, payload } = JSON.parse(event.data) as {
      type: string
      payload: Record<string, unknown>
    }

    switch (type) {
      case 'pong':
        lastPongAt = Date.now()
        break
      case 'update':
        handleUpdate(
          payload as { path: string; changes: string[]; boundary?: string; timestamp?: number }
        )
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

    if (heartbeatTimer) {
      clearInterval(heartbeatTimer)
      heartbeatTimer = undefined
    }

    reconnectTimer = setTimeout(connect, nextReconnectDelay())
  }
}

// Full-jitter exponential backoff: delay = min(MAX, BASE * 2^attempt) * rand().
// Caps out at RECONNECT_MAX and is randomized across [0, cap] so concurrent
// tabs don't retry in lockstep after a dev-server restart.
function nextReconnectDelay() {
  const exponent = Math.min(reconnectAttempts, 16)
  const cap = Math.min(RECONNECT_MAX, RECONNECT_BASE * 2 ** exponent)
  reconnectAttempts += 1
  return Math.floor(Math.random() * cap)
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
    await applyHMRUpdate(boundary, path, timestamp ?? Date.now())
    return
  }

  location.reload()
}

async function applyHMRUpdate(boundary: string, changedPath: string, timestamp: number) {
  const boundaryMatch = findHotModule(boundary)

  if (!boundaryMatch) {
    location.reload()
    return
  }

  const [boundaryUrl, boundaryModule] = boundaryMatch
  const changedUrl = findHotModule(changedPath)?.[0] ?? resolveAcceptedUrl(boundaryUrl, changedPath)
  const targetModule = hotModules.get(changedUrl) ?? boundaryModule
  const savedCallbacks = [...boundaryModule.callbacks]

  const newData: Record<string, unknown> = {}
  for (const cb of targetModule.disposeCallbacks) {
    cb(newData)
  }
  dataMap.set(changedUrl, newData)

  try {
    const changedModule = await importVersion(changedUrl, timestamp)

    for (const cb of savedCallbacks) {
      if (cb.kind === 'self' && changedUrl === boundaryUrl) {
        cb.fn(changedModule)
      } else if (cb.kind === 'single' && acceptsChanged(cb, boundaryUrl, changedUrl)) {
        cb.fn(changedModule)
      } else if (cb.kind === 'multi' && acceptsChanged(cb, boundaryUrl, changedUrl)) {
        cb.fn(
          await Promise.all(
            cb.deps.map((dep) => importVersion(resolveAcceptedUrl(boundaryUrl, dep), timestamp))
          )
        )
      }
    }

    console.log(`[Volt] HMR update: ${changedUrl}`)
  } catch (err) {
    console.error(`[Volt] HMR update failed for ${changedUrl}`, err)
    location.reload()
  }
}

function findHotModule(path: string): [string, HotModule] | undefined {
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

function acceptsChanged(callback: HotCallback, ownerUrl: string, changedUrl: string) {
  return callback.deps.some((dep) => sameModuleUrl(resolveAcceptedUrl(ownerUrl, dep), changedUrl))
}

function resolveAcceptedUrl(ownerUrl: string, specifier: string) {
  if (specifier.startsWith('/')) {
    return specifier
  }

  const resolved = new URL(specifier, new URL(ownerUrl, location.origin)).pathname
  const extension = resolved.split('/').pop()?.includes('.')

  return extension ? resolved : `${resolved}.ts`
}

function sameModuleUrl(left: string, right: string) {
  return left === right || stripExtension(left) === stripExtension(right)
}

function stripExtension(url: string) {
  return url.replace(/\.[^/.?]+(?=\?|$)/, '')
}

function importVersion(url: string, timestamp: number) {
  return import(/* @vite-ignore */ `${url}${url.includes('?') ? '&' : '?'}t=${timestamp}`)
}

export function updateStyle(id: string, css: string) {
  let style = document.querySelector<HTMLStyleElement>(`style[data-volt-id="${id}"]`)

  if (!style) {
    style = document.createElement('style')
    style.setAttribute('data-volt-id', id)
    document.head.appendChild(style)
  }

  style.textContent = css
}

export function removeStyle(id: string) {
  document.querySelector<HTMLStyleElement>(`style[data-volt-id="${id}"]`)?.remove()
}

async function updateStyles(path: string) {
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

  const styles = document.querySelectorAll<HTMLStyleElement>('style[data-volt-id]')

  for (const style of styles) {
    const id = style.getAttribute('data-volt-id')

    if (id && (id.includes(path) || path.includes(id.replace(/^\//, '')))) {
      const params = id.includes('?') ? '&t=' : '?import&t='
      const url = `${id}${params}${Date.now()}`
      await import(/* @vite-ignore */ url)
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
