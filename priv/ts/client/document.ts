import { Idiomorph } from 'idiomorph'
import { pageReload } from './reload'

const ETAG = 'data-volt-etag'
const MORPH = 'data-volt-morph'

let revalidation: Promise<void> | undefined

// The server-rendered HTML may have changed. A page that carries the entity tag
// of its HTML asks the server, which answers 304 when it has not. Otherwise the
// page is patched in place when it opted in and the change allows it, and
// reloaded when not.
export function revalidateDocument() {
  revalidation ??= updateDocument().finally(() => {
    revalidation = undefined
  })

  return revalidation
}

async function updateDocument() {
  const client = document.querySelector(`script[${ETAG}]`)
  const etag = client?.getAttribute(ETAG)
  if (!client || !etag) return pageReload()

  let response: Response

  try {
    response = await fetch(location.href, {
      headers: { 'If-None-Match': etag, Accept: 'text/html' },
      cache: 'no-store'
    })
  } catch {
    return pageReload()
  }

  if (response.status === 304) return

  const preserve = client.getAttribute(MORPH)
  const nextEtag = response.headers.get('etag')
  if (preserve === null || !response.ok || !nextEtag) return pageReload()

  const next = new DOMParser().parseFromString(await response.text(), 'text/html')
  if (!morphDocument(next, preserve)) return pageReload()

  document.querySelector(`script[${ETAG}]`)?.setAttribute(ETAG, nextEtag)
  document.dispatchEvent(new CustomEvent('volt:document-updated'))
  console.log('[Volt] Document updated')
}

/**
 * Patch the page to match `next`, the freshly rendered document.
 *
 * Returns false, changing nothing, when the difference cannot be applied by
 * patching: scripts do not run again, stylesheets are not reloaded, and
 * elements matching `preserve` are owned by client code such as a mounted
 * component.
 */
export function morphDocument(next: Document, preserve: string) {
  if (!sameItems(scripts(document), scripts(next))) return false
  if (!sameItems(stylesheets(document), stylesheets(next))) return false

  const preserved = preserve ? [...document.querySelectorAll(preserve)] : []
  if (!samePreserved(preserved, preserve ? [...next.querySelectorAll(preserve)] : [])) return false

  const owned = (node: Node) => preserve !== '' && node instanceof Element && node.matches(preserve)

  document.title = next.title

  // Morphing an element's children completes synchronously; the promise is for
  // whole documents, whose head may load new assets.
  void Idiomorph.morph(document.body, next.body, {
    morphStyle: 'innerHTML',
    callbacks: {
      beforeNodeMorphed: (node) => !owned(node),
      beforeNodeRemoved: (node) => !owned(node),
      beforeNodeAdded: (node) => !owned(node)
    }
  })

  return true
}

function sameItems(current: string[], next: string[]) {
  return current.length === next.length && current.every((item, index) => item === next[index])
}

// Scripts the browser runs. Data blocks such as JSON are content and are patched.
function scripts(doc: Document) {
  return [...doc.querySelectorAll('script')]
    .filter((script) => ['', 'module', 'text/javascript'].includes(script.type))
    .map((script) => `${script.type}|${script.getAttribute('src') ?? ''}|${script.textContent}`)
}

function stylesheets(doc: Document) {
  const links = [...doc.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]')].map((link) =>
    stylesheetUrl(link.getAttribute('href') ?? '')
  )

  // Volt adds and updates its own `<style data-volt-id>` elements.
  const styles = [...doc.querySelectorAll('style:not([data-volt-id])')].map(
    (style) => style.textContent ?? ''
  )

  return [...links, ...styles]
}

// A stylesheet update leaves a cache-busting `t` parameter on the link.
function stylesheetUrl(href: string) {
  const url = new URL(href, location.href)
  url.searchParams.delete('t')
  return url.toString()
}

// Client code may add attributes to an element it owns, such as a mount marker,
// so only the attributes the server rendered are compared.
function samePreserved(current: Element[], next: Element[]) {
  return (
    current.length === next.length &&
    next.every((element, index) =>
      [...element.attributes].every(
        (attribute) => current[index]?.getAttribute(attribute.name) === attribute.value
      )
    )
  )
}
