import { html, render } from 'lit-html'
import { unsafeHTML } from 'lit-html/directives/unsafe-html.js'

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

const TAG = 'volt-error-overlay'

// Colors from the Volt logo: purple to cyan on deep purple.
const styles = html`<style>
  /* Page styles beat :host rules, so the host only positions the overlay. */
  :host {
    display: block;
    position: fixed;
    inset: 0;
    z-index: 99999;
  }
  .backdrop {
    box-sizing: border-box;
    height: 100%;
    overflow: auto;
    padding: 6vh 16px;
    background: rgba(20, 8, 40, 0.72);
    font: 14px/1.6 ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  .panel {
    box-sizing: border-box;
    max-width: 960px;
    margin: 0 auto;
    overflow: hidden;
    color: #ece6f7;
    background: #1a0f2e;
    border: 1px solid #3a2466;
    border-radius: 10px;
    box-shadow: 0 16px 48px rgba(10, 4, 24, 0.6);
  }
  .panel::before {
    content: '';
    display: block;
    height: 4px;
    background: linear-gradient(90deg, #9b3dea, #1de4ef);
  }
  .body {
    padding: 20px 28px 24px;
  }
  h1 {
    margin: 0;
    font: inherit;
    font-weight: bold;
    color: #ff6b9a;
  }
  section {
    margin-top: 1.25em;
  }
  .location {
    color: #1de4ef;
  }
  .message {
    color: #ff6b9a;
    white-space: pre-wrap;
  }
  pre {
    margin: 0.75em 0 0;
    padding: 12px 16px;
    overflow-x: auto;
    font: inherit;
    color: #e6edf3;
    background: #120a22;
    border: 1px solid #2a1a48;
    border-radius: 6px;
  }
  .hint {
    margin-top: 0.5em;
    color: #9b3dea;
    white-space: pre-wrap;
  }
  footer {
    margin-top: 1.5em;
    font-size: 12px;
    color: #8a7aa8;
  }
</style>`

class VoltErrorOverlay extends HTMLElement {
  private root = this.attachShadow({ mode: 'open' })

  constructor() {
    super()
    this.addEventListener('click', (event) => {
      const target = event.composedPath()[0]
      if (target instanceof Element && target.classList.contains('backdrop')) this.remove()
    })
  }

  show(errors: VoltError[], title: string) {
    render(
      html`${styles}
        <div class="backdrop">
          <div class="panel">
            <div class="body">
            <h1>${errors.length > 1 ? `${title} · ${errors.length}` : title}</h1>
            ${errors.map(errorTemplate)}
            <footer>Fix the error to dismiss this overlay, or click outside it.</footer>
          </div>
        </div>
      </div>`,
      this.root
    )
  }
}

function errorTemplate(error: VoltError) {
  const location = locationText(error)

  return html`<section>
    ${location ? html`<div class="location">${location}</div>` : null}
    <div class="message">${error.message}</div>
    ${
      error.frame
        ? // The dev server builds `frame_html` from escaped, syntax-highlighted source.
          html`<pre>${error.frame_html ? unsafeHTML(error.frame_html) : error.frame}</pre>`
        : null
    }
    ${error.hint ? html`<div class="hint">${error.hint}</div>` : null}
  </section>`
}

export function renderErrorOverlay(errors: VoltError[], options: VoltErrorOverlayOptions = {}) {
  const title = options.title ?? 'Build error'
  console.error(`[Volt] ${title}:\n${errors.map(errorText).join('\n\n')}`)

  if (typeof document === 'undefined') {
    return
  }

  if (!customElements.get(TAG)) customElements.define(TAG, VoltErrorOverlay)

  clearErrorOverlay()
  const overlay = document.createElement(TAG) as VoltErrorOverlay
  overlay.show(errors, title)
  document.body.appendChild(overlay)
}

export function clearErrorOverlay() {
  if (typeof document !== 'undefined') {
    document.querySelector(TAG)?.remove()
  }
}

function locationText({ file, line, column }: VoltError) {
  if (!file) return null
  if (!line) return file
  return column ? `${file}:${line}:${column}` : `${file}:${line}`
}

function errorText(error: VoltError) {
  return [locationText(error), error.message, error.frame, error.hint].filter(Boolean).join('\n')
}
