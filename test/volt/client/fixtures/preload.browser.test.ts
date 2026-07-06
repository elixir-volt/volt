import { test, expect } from 'volt:test'
import { preload, preloadDep } from 'volt:client/preload'

test('preloads JavaScript dependencies with modulepreload links', async () => {
  await preloadDep('/assets/preload-module.js')

  const link = document.querySelector<HTMLLinkElement>('link[href="/assets/preload-module.js"]')

  expect(link).toBeDefined()
  expect(link?.rel).toBe('modulepreload')
})

test('preloads stylesheet dependencies with stylesheet links', async () => {
  const promise = preloadDep('/assets/preload-style.css')
  const link = document.querySelector<HTMLLinkElement>('link[href="/assets/preload-style.css"]')

  expect(link).toBeDefined()
  expect(link?.rel).toBe('stylesheet')

  link?.dispatchEvent(new Event('load'))
  await promise
})

test('does not append duplicate preload links', async () => {
  await preloadDep('/assets/preload-once.js')
  await preloadDep('/assets/preload-once.js')

  expect(document.querySelectorAll('link[href="/assets/preload-once.js"]')).toHaveLength(1)
})

test('dispatches volt:preloadError when dependency loading fails', async () => {
  let eventDetail: unknown
  const failed = new Error('stylesheet failed')

  window.addEventListener(
    'volt:preloadError',
    (event) => {
      eventDetail = (event as CustomEvent).detail
    },
    { once: true }
  )

  const promise = preload(() => Promise.resolve('loaded'), ['/assets/preload-fails.css'])
  const link = document.querySelector<HTMLLinkElement>('link[href="/assets/preload-fails.css"]')

  link?.dispatchEvent(new ErrorEvent('error', { error: failed }))

  try {
    await promise
    throw new Error('expected preload to reject')
  } catch (error) {
    expect(error).toBeDefined()
  }

  expect(eventDetail).toBeDefined()
})
