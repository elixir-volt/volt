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

test('refreshes matching stylesheet links for CSS updates', async () => {
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = 'https://example.test/assets/site.css'
  link.dataset.testStyle = 'true'
  document.head.appendChild(link)

  await updateStyles('/assets/site.css')

  expect(link.href).toContain('/assets/site.css')
  expect(link.href).toContain('t=')
})
