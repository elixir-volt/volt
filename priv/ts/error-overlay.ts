function renderErrorOverlay(message: string) {
  console.error(`[Volt] Compilation error:\n${message}`)

  if (typeof document === 'undefined') {
    return
  }

  const overlay = document.createElement('div')
  overlay.style.cssText =
    'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto'
  overlay.textContent = `[Volt] Compilation error:\n\n${message}`
  document.body.appendChild(overlay)
}
