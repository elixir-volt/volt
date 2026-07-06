import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import { add, frameworkName } from './arithmetic'

describe('volt:test core', () => {
  test('toBe compares with Object.is', () => {
    expect(add(1, 2)).toBe(3)
    expect(Number.NaN).toBe(Number.NaN)
  })

  test('toEqual compares arrays and objects deeply', () => {
    expect({ name: 'volt', features: ['exunit', 'typescript'] }).toEqual({
      name: 'volt',
      features: ['exunit', 'typescript']
    })
  })

  test('toContain supports strings and arrays', () => {
    expect(frameworkName).toContain('volt')
    expect(['js', 'ts', 'exs']).toContain('ts')
  })

  test('toThrow checks thrown messages', () => {
    expect(() => {
      throw new Error('boom')
    }).toThrow('boom')
  })

  test('not negates matchers', () => {
    expect(1 + 1).not.toBe(3)
    expect({ value: 1 }).not.toEqual({ value: 2 })
    expect('volt').not.toContain('vite')
    expect(() => {}).not.toThrow()
  })

  test('common truthiness and defined matchers', () => {
    expect('value').toBeDefined()
    expect(undefined).toBeUndefined()
    expect(true).toBeTruthy()
    expect(0).toBeFalsy()
    expect(null).toBeNull()
    expect(Number.NaN).toBeNaN()
  })

  test('toBeCloseTo compares floating point values', () => {
    expect(0.1 + 0.2).toBeCloseTo(0.3, 5)
    expect(0.1 + 0.2).not.toBeCloseTo(0.4, 5)
  })

  test('async tests can await promises', async () => {
    const value: number = await Promise.resolve(42)
    expect(value).toBe(42)
  })
})

describe('volt:test modifiers', () => {
  describe.skip('skipped suite', () => {
    test('suite skip does not execute body', () => {
      throw new Error('should not run')
    })
  })

  describe.todo('todo suite', () => {
    test('suite todo is collected as skipped')
  })

  test.skip('skip does not execute body', () => {
    throw new Error('should not run')
  })

  test.todo('todo is collected as skipped')

  test(
    'object options can skip and carry tags',
    { skip: 'documented skip', tags: ['slow'] },
    () => {
      throw new Error('should not run')
    }
  )

  test('context skip can skip dynamically', ({ skip }) => {
    skip('dynamic skip')
    throw new Error('should not run')
  })
})

describe('volt:test hooks', () => {
  let value = 0
  let afterCount = 0

  beforeEach(() => {
    value = 41
  })

  afterEach(() => {
    afterCount += 1
  })

  test('beforeEach runs before tests', () => {
    expect(value + 1).toBe(42)
    expect(afterCount).toBe(0)
  })

  test('afterEach does not run before the current test body', () => {
    expect(value).toBe(41)
    expect(afterCount).toBe(0)
  })
})
