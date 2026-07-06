import { test, expect, beforeEach } from 'volt:test'
import { renderErrorOverlay } from 'volt:client/overlay'

beforeEach(() => {
  document.body.innerHTML = ''
})

test('renders build errors into the browser overlay', () => {
  renderErrorOverlay('syntax exploded', { title: 'Compile failed' })

  const overlay = document.getElementById('volt-error-overlay')

  expect(overlay).toBeDefined()
  expect(overlay?.textContent).toContain('[Volt] Compile failed:')
  expect(overlay?.textContent).toContain('syntax exploded')
})

test('updates an existing browser overlay instead of appending duplicates', () => {
  renderErrorOverlay('first failure')
  renderErrorOverlay({ message: 'second failure' })

  const overlays = document.querySelectorAll('#volt-error-overlay')

  expect(overlays).toHaveLength(1)
  expect(overlays[0]?.textContent).toContain('second failure')
})

test('dismissible browser overlays remove themselves when clicked', () => {
  renderErrorOverlay('dismiss me', { dismissible: true })

  const overlay = document.getElementById('volt-error-overlay')
  expect(overlay).toBeDefined()

  overlay?.click()

  expect(document.getElementById('volt-error-overlay')).toBeNull()
})
