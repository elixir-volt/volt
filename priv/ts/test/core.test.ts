import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import { add, frameworkName } from './fixture'

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

  test('async tests can await promises', async () => {
    const value: number = await Promise.resolve(42)
    expect(value).toBe(42)
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

  test('afterEach ran after the previous test', () => {
    expect(value).toBe(41)
    expect(afterCount).toBe(1)
  })
})
