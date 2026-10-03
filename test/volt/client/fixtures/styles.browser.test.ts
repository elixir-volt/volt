import { test, expect, beforeEach } from 'volt:test'
import { removeStyle, updateStyle, updateStyles } from 'volt:client/styles'

beforeEach(() => {
  document.head.querySelectorAll('style[data-volt-id], link[data-test-style]').forEach((node) =>
    node.remove()
  )
})

test('creates and updates one style tag per Volt style id', () => {
  updateStyle('/assets/app.css?import', '.target { color: red; }')
  updateStyle('/assets/app.css?import', '.target { color: blue; }')

  const styles = document.head.querySelectorAll<HTMLStyleElement>(
    'style[data-volt-id="/assets/app.css?import"]'
  )

  expect(styles).toHaveLength(1)
  expect(styles[0]?.textContent).toContain('blue')
})

test('removes style tags by Volt style id', () => {
  updateStyle('/assets/remove.css?import', '.remove { color: red; }')
  removeStyle('/assets/remove.css?import')

  expect(document.head.querySelector('style[data-volt-id="/assets/remove.css?import"]')).toBeNull()
})

test('replaces matching stylesheet links once the refreshed stylesheet settles', async () => {
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = new URL('./assets/site.css', location.href).href
  link.dataset.testStyle = 'true'
  document.head.appendChild(link)

  await updateStyles('/assets/site.css')

  const links = document.head.querySelectorAll<HTMLLinkElement>('link[data-test-style]')

  expect(links).toHaveLength(1)
  expect(links[0]).not.toBe(link)
  expect(links[0]?.href).toContain('/assets/site.css')
  expect(links[0]?.href).toContain('t=')
})

test('keeps the current stylesheet applied until the refreshed one settles', () => {
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = new URL('./assets/pending.css', location.href).href
  link.dataset.testStyle = 'true'
  document.head.appendChild(link)

  void updateStyles('/assets/pending.css')

  const links = document.head.querySelectorAll<HTMLLinkElement>('link[data-test-style]')

  expect(links).toHaveLength(2)
  expect(links[0]).toBe(link)
  expect(links[1]?.href).toContain('t=')
})
