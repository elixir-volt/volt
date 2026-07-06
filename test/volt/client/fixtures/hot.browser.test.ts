import { test, expect, beforeEach } from 'volt:test'
import { createHotContext, hotModuleFor, preserveHotData } from 'volt:client/hot'

beforeEach(() => {
  createHotContext(`/assets/hot-${Date.now()}-${Math.random()}.ts`)
})

test('creates hot contexts that self accept updates', () => {
  const hot = createHotContext('/assets/self.ts')
  const callback = () => undefined

  hot.accept(callback)

  const mod = hotModuleFor('/assets/self.ts')

  expect(mod?.acceptSelf).toBe(true)
  expect(mod?.callbacks).toHaveLength(1)
  expect(mod?.callbacks[0]?.kind).toBe('self')
  expect(mod?.callbacks[0]?.deps).toEqual(['/assets/self.ts'])
})

test('tracks accepted dependency callbacks', () => {
  const hot = createHotContext('/assets/owner.ts')

  hot.accept('./dep', () => undefined)
  hot.accept(['./a', './b'], () => undefined)

  const mod = hotModuleFor('/assets/owner.ts')

  expect(mod?.callbacks).toHaveLength(2)
  expect(mod?.callbacks[0]?.kind).toBe('single')
  expect(mod?.callbacks[0]?.deps).toEqual(['./dep'])
  expect(mod?.callbacks[1]?.kind).toBe('multi')
  expect(mod?.callbacks[1]?.deps).toEqual(['./a', './b'])
})

test('resets callbacks on recreate while preserving stored hot data', () => {
  const first = createHotContext('/assets/stateful.ts')
  first.accept(() => undefined)
  first.dispose((data) => {
    data.value = 42
  })

  preserveHotData('/assets/stateful.ts', { value: 42 })

  const second = createHotContext('/assets/stateful.ts')
  const mod = hotModuleFor('/assets/stateful.ts')

  expect(second.data).toEqual({ value: 42 })
  expect(mod?.callbacks).toHaveLength(0)
  expect(mod?.disposeCallbacks).toHaveLength(0)
  expect(mod?.acceptSelf).toBe(false)
})
