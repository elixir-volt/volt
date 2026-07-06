import { assertionError } from './errors'
import { deepEqual, format } from './format'

export function expect(actual: unknown) {
  return createExpectation(actual, false)
}

function createExpectation(actual: unknown, negated: boolean): Volt.Test.Matchers {
  const match = (ok: boolean, message: string, expected?: unknown) => {
    if (negated ? ok : !ok) {
      throw assertionError(message, expected, actual)
    }
  }

  const matchers: Volt.Test.Matchers = {
    get not() {
      return createExpectation(actual, !negated)
    },

    toBe(expected: unknown) {
      match(
        Object.is(actual, expected),
        `Expected ${format(actual)} ${notText(negated)}to be ${format(expected)}`,
        expected
      )
    },

    toEqual(expected: unknown) {
      match(
        deepEqual(actual, expected),
        `Expected ${format(actual)} ${notText(negated)}to equal ${format(expected)}`,
        expected
      )
    },

    toContain(expected: unknown) {
      const ok =
        typeof actual === 'string'
          ? actual.includes(String(expected))
          : Array.isArray(actual) && actual.includes(expected)

      match(
        ok,
        `Expected ${format(actual)} ${notText(negated)}to contain ${format(expected)}`,
        expected
      )
    },

    toBeDefined() {
      match(
        actual !== undefined,
        `Expected ${format(actual)} ${notText(negated)}to be defined`,
        undefined
      )
    },

    toBeUndefined() {
      match(
        actual === undefined,
        `Expected ${format(actual)} ${notText(negated)}to be undefined`,
        undefined
      )
    },

    toBeTruthy() {
      match(Boolean(actual), `Expected ${format(actual)} ${notText(negated)}to be truthy`, true)
    },

    toBeFalsy() {
      match(!actual, `Expected ${format(actual)} ${notText(negated)}to be falsy`, false)
    },

    toBeNull() {
      match(actual === null, `Expected ${format(actual)} ${notText(negated)}to be null`, null)
    },

    toBeNaN() {
      match(
        Number.isNaN(actual),
        `Expected ${format(actual)} ${notText(negated)}to be NaN`,
        Number.NaN
      )
    },

    toBeCloseTo(expected: number, digits = 2) {
      const actualNumber = Number(actual)
      const tolerance = 10 ** -digits / 2
      const ok = Number.isFinite(actualNumber) && Math.abs(actualNumber - expected) < tolerance
      match(
        ok,
        `Expected ${format(actual)} ${notText(negated)}to be close to ${format(expected)}`,
        expected
      )
    },

    toThrow(expected?: string | RegExp) {
      if (typeof actual !== 'function') {
        throw assertionError(
          `Expected ${format(actual)} to be a function`,
          'function',
          typeof actual
        )
      }

      let thrown: unknown

      try {
        ;(actual as () => unknown)()
      } catch (error) {
        thrown = error
      }

      let ok = thrown !== undefined

      if (ok && expected !== undefined) {
        const message = thrown instanceof Error ? thrown.message : String(thrown)
        ok =
          expected instanceof RegExp ? expected.test(message) : message.includes(String(expected))
      }

      match(ok, `Expected function ${notText(negated)}to throw`, expected)
    }
  }

  return matchers
}

function notText(negated: boolean) {
  return negated ? 'not ' : ''
}
