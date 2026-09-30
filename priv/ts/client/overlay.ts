const VOLT_ERROR_OVERLAY_ID = 'volt-error-overlay'

// Colors from the Volt logo: a purple-to-cyan drop and bolt on deep purple.
const PURPLE = '#9b3dea'
const CYAN = '#1de4ef'
const ERROR = '#ff6b9a'
const DIM = '#8a7aa8'

const OVERLAY_STYLE =
  'position:fixed;inset:0;z-index:99999;background:rgba(20,8,40,0.72);padding:6vh 16px;overflow:auto'
const PANEL_STYLE = `box-sizing:border-box;max-width:960px;margin:0 auto;overflow:hidden;background:#1a0f2e;border:1px solid #3a2466;border-radius:10px;box-shadow:0 16px 48px rgba(10,4,24,0.6);color:#ece6f7;font:14px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace`
const BAR_STYLE = `height:4px;background:linear-gradient(90deg,${PURPLE},${CYAN})`
const FRAME_STYLE =
  'margin:0.75em 0 0;padding:12px 16px;background:#120a22;border:1px solid #2a1a48;border-radius:6px;overflow-x:auto;color:#e6edf3;font:inherit'

const LOGO = `<svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><defs><linearGradient id="volt-overlay-logo" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${PURPLE}"/><stop offset="1" stop-color="${CYAN}"/></linearGradient></defs><path d="M14.5 1.5C14.5 1.5 21.5 10 21.5 15a7 7 0 0 1-14 0c0-5 7-13.5 7-13.5z" fill="url(#volt-overlay-logo)"/><path d="M9.5 6.5 3.5 14.5h4l-2 7.5 7.5-10h-4.5l2-5.5z" fill="url(#volt-overlay-logo)" stroke="#1a0f2e" stroke-width="1.5" stroke-linejoin="round"/></svg>`

export type VoltError = {
  message: string
  file?: string | null
  line?: number | null
  column?: number | null
  hint?: string | null
  frame?: string | null
  frame_html?: string | null
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

  const overlay = block('div', null, OVERLAY_STYLE)
  overlay.id = VOLT_ERROR_OVERLAY_ID
  overlay.onclick = (event) => {
    if (event.target === overlay) overlay.remove()
  }

  const panel = block('div', null, PANEL_STYLE)
  const body = block('div', null, 'padding:20px 28px 24px')
  panel.append(block('div', null, BAR_STYLE), body)
  body.append(header(title, errors.length))

  for (const error of errors) {
    const entry = block('section', null, 'margin-top:1.25em')
    const location = locationText(error)

    if (location) entry.append(block('div', location, `color:${CYAN}`))
    entry.append(block('div', error.message, `color:${ERROR};white-space:pre-wrap`))
    if (error.frame) {
      const frame = block('pre', error.frame, FRAME_STYLE)
      // Built by the dev server from escaped, syntax-highlighted source.
      if (error.frame_html) frame.innerHTML = error.frame_html
      entry.append(frame)
    }
    if (error.hint) {
      entry.append(
        block('div', error.hint, `margin-top:0.5em;color:${PURPLE};white-space:pre-wrap`)
      )
    }

    body.append(entry)
  }

  body.append(
    block(
      'div',
      'Fix the error to dismiss this overlay, or click outside it.',
      `margin-top:1.5em;color:${DIM};font-size:12px`
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

function header(title: string, count: number) {
  const row = block('div', null, 'display:flex;align-items:center;gap:10px')
  const logo = block('span', null, 'display:flex')
  logo.innerHTML = LOGO
  row.append(
    logo,
    block('span', 'Volt', 'font-weight:bold;letter-spacing:0.02em'),
    block('span', count > 1 ? `${title} · ${count}` : title, `color:${ERROR};font-weight:bold`)
  )
  return row
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
