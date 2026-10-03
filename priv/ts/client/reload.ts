const RELOAD_DELAY = 20

let timer: ReturnType<typeof setTimeout> | undefined

// One save can produce several messages that each ask for a reload, such as a
// template that is also a Tailwind source. Reloading once covers all of them.
export function pageReload() {
  if (timer) clearTimeout(timer)
  timer = setTimeout(() => location.reload(), RELOAD_DELAY)
}

const ETAG_ATTRIBUTE = 'data-volt-etag'

let revalidation: Promise<void> | undefined

// The server-rendered HTML may have changed. A page that carries the entity tag
// of its HTML asks the server and reloads only if it did.
export function revalidateDocument() {
  revalidation ??= documentChanged()
    .then((changed) => {
      if (changed) pageReload()
    })
    .finally(() => {
      revalidation = undefined
    })

  return revalidation
}

async function documentChanged() {
  const etag = document.querySelector(`script[${ETAG_ATTRIBUTE}]`)?.getAttribute(ETAG_ATTRIBUTE)
  if (!etag) return true

  try {
    const response = await fetch(location.href, {
      headers: { 'If-None-Match': etag, Accept: 'text/html' },
      cache: 'no-store'
    })

    return response.status !== 304
  } catch {
    return true
  }
}
