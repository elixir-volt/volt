import { test, expect, beforeEach } from 'volt:test'
import { clearErrorOverlay, renderErrorOverlay } from 'volt:client/overlay'

beforeEach(() => {
  document.body.innerHTML = ''
})

function overlayText() {
  return document.querySelector('volt-error-overlay')?.shadowRoot?.textContent ?? ''
}

test('renders build errors into the browser overlay', () => {
  renderErrorOverlay([
    { title: 'Compile failed', message: 'syntax exploded', file: 'app.ts', line: 3 }
  ])

  expect(overlayText()).toContain('Compile failed')
  expect(overlayText()).toContain('syntax exploded')
  expect(overlayText()).toContain('app.ts:3')
})

test('replaces an existing browser overlay instead of appending duplicates', () => {
  renderErrorOverlay([{ title: 'Build error', message: 'first failure' }])
  renderErrorOverlay([{ title: 'Build error', message: 'second failure' }])

  expect(document.querySelectorAll('volt-error-overlay')).toHaveLength(1)
  expect(overlayText()).toContain('second failure')
  expect(overlayText()).not.toContain('first failure')
})

test('counts errors with different titles under one heading', () => {
  renderErrorOverlay([
    { title: 'Build error', message: 'first failure' },
    { title: 'Render error', message: 'second failure' }
  ])

  expect(overlayText()).toContain('Errors · 2')
})

test('removes the browser overlay when errors clear or the backdrop is clicked', () => {
  renderErrorOverlay([{ title: 'Build error', message: 'dismiss me' }])

  const backdrop = document
    .querySelector('volt-error-overlay')
    ?.shadowRoot?.querySelector('.backdrop')

  backdrop?.dispatchEvent(new MouseEvent('click', { bubbles: true, composed: true }))
  expect(document.querySelector('volt-error-overlay')).toBeNull()

  renderErrorOverlay([{ title: 'Build error', message: 'clear me' }])
  clearErrorOverlay()
  expect(document.querySelector('volt-error-overlay')).toBeNull()
})
