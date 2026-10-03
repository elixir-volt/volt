import { pageReload } from './reload'

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

const outdatedLinks = new WeakSet<HTMLLinkElement>()

// Changing `href` in place leaves the page unstyled until the new stylesheet
// arrives. A second tag keeps the old rules applied until the new ones load.
function refreshLink(link: HTMLLinkElement) {
  return new Promise<void>((resolve) => {
    const url = new URL(link.href)
    url.searchParams.set('t', Date.now().toString())

    const next = link.cloneNode() as HTMLLinkElement
    next.href = url.toString()

    const removeOutdated = () => {
      link.remove()
      resolve()
    }

    next.addEventListener('load', removeOutdated)
    next.addEventListener('error', removeOutdated)
    outdatedLinks.add(link)
    link.after(next)
  })
}

export async function updateStyles(path: string) {
  const links = [...document.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]')].filter(
    (link) => {
      const href = link.getAttribute('href')
      return !outdatedLinks.has(link) && href && (href.includes(path) || path.endsWith('.css'))
    }
  )

  await Promise.all(links.map(refreshLink))
  let updated = links.length > 0

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
    pageReload()
  }
}
