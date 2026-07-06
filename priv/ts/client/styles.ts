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

export async function updateStyles(path: string) {
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
