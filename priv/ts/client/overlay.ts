const VOLT_ERROR_OVERLAY_ID = 'volt-error-overlay'
const VOLT_ERROR_OVERLAY_STYLE =
  'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto'

type VoltErrorOverlayOptions = {
  title?: string
  dismissible?: boolean
}

export function renderErrorOverlay(reason: unknown, options: VoltErrorOverlayOptions = {}) {
  const title = options.title ?? 'Build error'
  console.error(`[Volt] ${title}:\n${messageFor(reason)}`)

  if (typeof document === 'undefined') {
    return
  }

  let overlay = document.getElementById(VOLT_ERROR_OVERLAY_ID)

  if (!overlay) {
    overlay = document.createElement('div')
    overlay.id = VOLT_ERROR_OVERLAY_ID
    document.body.appendChild(overlay)
  }

  overlay.style.cssText = options.dismissible
    ? `${VOLT_ERROR_OVERLAY_STYLE};cursor:pointer`
    : VOLT_ERROR_OVERLAY_STYLE
  overlay.onclick = options.dismissible ? () => overlay?.remove() : null
  overlay.textContent = `[Volt] ${title}:\n\n${messageFor(reason)}`
}

function messageFor(reason: unknown) {
  return typeof reason === 'string' ? reason : JSON.stringify(reason, null, 2)
}
