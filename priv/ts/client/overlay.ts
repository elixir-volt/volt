const VOLT_ERROR_OVERLAY_ID = 'volt-error-overlay'
const VOLT_ERROR_OVERLAY_STYLE =
  'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.66);padding:6vh 16px;overflow:auto'
const VOLT_ERROR_PANEL_STYLE =
  'box-sizing:border-box;max-width:960px;margin:0 auto;padding:24px 28px;background:#181818;border-top:6px solid #ff5555;border-radius:6px;box-shadow:0 12px 32px rgba(0,0,0,0.5);color:#e8e8e8;font:14px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace'

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
  overlay.onclick = (event) => {
    if (event.target === overlay) overlay.remove()
  }

  const panel = block('div', null, VOLT_ERROR_PANEL_STYLE)
  panel.append(block('div', `[Volt] ${title}`, 'color:#ff5555;font-weight:bold'))

  for (const error of errors) {
    const entry = block('section', null, 'margin-top:1.25em')
    const location = locationText(error)

    if (location) entry.append(block('div', location, 'color:#9aa0a6'))
    entry.append(block('div', error.message, 'color:#ff8080;white-space:pre-wrap'))
    if (error.frame) {
      entry.append(
        block(
          'pre',
          error.frame,
          'margin:0.75em 0 0;padding:12px 16px;background:#0f0f0f;border-radius:4px;overflow-x:auto;color:#e8e8e8;font:inherit'
        )
      )
    }
    if (error.hint) {
      entry.append(block('div', error.hint, 'margin-top:0.5em;color:#8ab4f8;white-space:pre-wrap'))
    }

    panel.append(entry)
  }

  panel.append(
    block(
      'div',
      'Fix the error to dismiss this overlay, or click outside it.',
      'margin-top:1.5em;color:#777;font-size:12px'
    )
  )
  overlay.append(panel)
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
