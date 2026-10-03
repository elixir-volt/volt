import { test, expect, beforeEach } from 'volt:test'
import { morphDocument } from 'volt:client/document'

function page(body: string, head = '') {
  return new DOMParser().parseFromString(
    `<!DOCTYPE html><html><head><title>Next</title>${head}</head><body>${body}</body></html>`,
    'text/html'
  )
}

beforeEach(() => {
  document.head.querySelectorAll('link[data-test], style[data-test]').forEach((node) => node.remove())
  document.body.innerHTML = '<main><h1 id="title">Hello</h1><p id="text">first</p></main>'
})

test('patches changed text and keeps the elements that did not change', () => {
  const title = document.getElementById('title')
  const text = document.getElementById('text')

  expect(morphDocument(page('<main><h1 id="title">Hello</h1><p id="text">second</p></main>'), '')).toBe(
    true
  )

  expect(document.getElementById('text')?.textContent).toBe('second')
  expect(document.getElementById('title')).toBe(title)
  expect(document.getElementById('text')).toBe(text)
  expect(document.title).toBe('Next')
})

test('patches attributes such as classes', () => {
  expect(morphDocument(page('<main class="wide"><h1 id="title">Hello</h1></main>'), '')).toBe(true)

  expect(document.querySelector('main')?.className).toBe('wide')
  expect(document.getElementById('text')).toBeNull()
})

test('refuses when the scripts the page runs differ', () => {
  const next = page('<main><p id="text">second</p></main><script>window.changed = true</script>')

  expect(morphDocument(next, '')).toBe(false)
  expect(document.getElementById('text')?.textContent).toBe('first')
})

test('patches data blocks, which the browser does not run', () => {
  const next = page('<main><script type="application/json" id="data">{"a":1}</script></main>')

  expect(morphDocument(next, '')).toBe(true)
  expect(document.getElementById('data')?.textContent).toBe('{"a":1}')
})

test('refuses when the stylesheets differ', () => {
  const next = page('<main></main>', '<style data-test>.a { color: red }</style>')

  expect(morphDocument(next, '')).toBe(false)
})

test('leaves elements owned by client code alone', () => {
  document.body.innerHTML =
    '<p id="text">first</p><div data-island="counter" data-props="{}" data-mounted><b>3 clicks</b></div>'

  const island = document.querySelector('[data-island]')

  const next = page('<p id="text">second</p><div data-island="counter" data-props="{}"></div>')

  expect(morphDocument(next, '[data-island]')).toBe(true)
  expect(document.getElementById('text')?.textContent).toBe('second')
  expect(document.querySelector('[data-island]')).toBe(island)
  expect(island?.innerHTML).toBe('<b>3 clicks</b>')
  expect(island?.hasAttribute('data-mounted')).toBe(true)
})

test('refuses when what the server renders for an owned element differs', () => {
  document.body.innerHTML = '<div data-island="counter" data-props="{&quot;start&quot;:1}"></div>'

  const changed = page('<div data-island="counter" data-props="{&quot;start&quot;:2}"></div>')
  const added = page('<div data-island="counter" data-props="{&quot;start&quot;:1}"></div><div data-island="other"></div>')

  expect(morphDocument(changed, '[data-island]')).toBe(false)
  expect(morphDocument(added, '[data-island]')).toBe(false)
})
