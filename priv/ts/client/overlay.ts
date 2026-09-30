const VOLT_ERROR_OVERLAY_ID = 'volt-error-overlay'
const VOLT_ERROR_OVERLAY_STYLE =
  'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#e8e8e8;font:14px/1.6 ui-monospace,monospace;padding:2em;overflow:auto;cursor:pointer'

export type VoltError = {
  message: string
  file?: string | null
  line?: number | null
  column?: number | null
  hint?: string | null
  frame?: string | null
}

type VoltErrorOverlayOptions = {
  title?: string
}

export function renderErrorOverlay(errors: VoltError[], options: VoltErrorOverlayOptions = {}) {
  const title = options.title ?? 'Build error'
  console.error(`[Volt] ${title}:\n${errors.map(errorText).join('\n\n')}`)

  if (typeof document === 'undefined') {
    return
  }

  clearErrorOverlay()

  const overlay = document.createElement('div')
  overlay.id = VOLT_ERROR_OVERLAY_ID
  overlay.style.cssText = VOLT_ERROR_OVERLAY_STYLE
  overlay.onclick = () => overlay.remove()
  overlay.append(block('div', `[Volt] ${title}`, 'color:#ff6b6b;font-weight:bold'))

  for (const error of errors) {
    const entry = block('section', null, 'margin-top:1.5em')
    const location = locationText(error)

    if (location) entry.append(block('div', location, 'color:#9aa0a6'))
    entry.append(block('div', error.message, 'color:#ff6b6b;white-space:pre-wrap'))
    if (error.frame) entry.append(block('pre', error.frame, 'margin:0.5em 0;color:#e8e8e8'))
    if (error.hint) entry.append(block('div', error.hint, 'color:#8ab4f8;white-space:pre-wrap'))

    overlay.append(entry)
  }

  document.body.appendChild(overlay)
}

export function clearErrorOverlay() {
  if (typeof document !== 'undefined') {
    document.getElementById(VOLT_ERROR_OVERLAY_ID)?.remove()
  }
}

function block(tag: string, text: string | null, style: string) {
  const element = document.createElement(tag)
  element.style.cssText = style
  if (text !== null) element.textContent = text
  return element
}

function locationText({ file, line, column }: VoltError) {
  if (!file) return null
  if (!line) return file
  return column ? `${file}:${line}:${column}` : `${file}:${line}`
}

function errorText(error: VoltError) {
  return [locationText(error), error.message, error.frame, error.hint].filter(Boolean).join('\n')
}
