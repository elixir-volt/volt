const __voltPreloaded = new Set<string>()

const __voltPreload = (load: () => Promise<unknown>, deps: string[]) =>
  Promise.all(deps.map(__voltPreloadDep))
    .then(load)
    .catch((error) => {
      window.dispatchEvent(new CustomEvent('volt:preloadError', { detail: error }))
      throw error
    })

function __voltPreloadDep(dep: string) {
  if (__voltPreloaded.has(dep) || document.querySelector(`link[href=${JSON.stringify(dep)}]`)) {
    return Promise.resolve()
  }

  __voltPreloaded.add(dep)

  const link = document.createElement('link')
  link.rel = dep.endsWith('.css') ? 'stylesheet' : 'modulepreload'
  link.href = dep
  document.head.appendChild(link)

  if (link.rel !== 'stylesheet') {
    return Promise.resolve()
  }

  return new Promise((resolve, reject) => {
    link.onload = resolve
    link.onerror = reject
  })
}
