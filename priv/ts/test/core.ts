type TestFunction = () => unknown | Promise<unknown>
type HookFunction = () => unknown | Promise<unknown>

interface RegisteredTest {
  id: number
  name: string
  suite: string[]
  beforeEach: HookFunction[]
  afterEach: HookFunction[]
  fn: TestFunction
}

interface SuiteContext {
  name?: string
  beforeEach: HookFunction[]
  afterEach: HookFunction[]
}

interface TestResult {
  id: number
  name: string
  fullName: string
  status: 'passed' | 'failed'
  duration: number
  error?: SerializedError
}

interface SerializedError {
  name: string
  message: string
  stack?: string
  expected?: unknown
  actual?: unknown
}

interface VoltTestState {
  tests: RegisteredTest[]
  suite: string[]
  suiteStack: SuiteContext[]
  nextId: number
}

const state: VoltTestState = {
  tests: [],
  suite: [],
  suiteStack: [newSuite()],
  nextId: 1
}

function reset() {
  state.tests = []
  state.suite = []
  state.suiteStack = [newSuite()]
  state.nextId = 1
}

function describe(name: string, fn: () => void) {
  state.suite.push(name)
  state.suiteStack.push(newSuite(name))

  try {
    fn()
  } finally {
    state.suiteStack.pop()
    state.suite.pop()
  }
}

function test(name: string, fn: TestFunction) {
  state.tests.push({
    id: state.nextId++,
    name,
    suite: [...state.suite],
    beforeEach: state.suiteStack.flatMap((suite) => suite.beforeEach),
    afterEach: state.suiteStack.flatMap((suite) => suite.afterEach).reverse(),
    fn
  })
}

function beforeEach(fn: HookFunction) {
  currentSuite().beforeEach.push(fn)
}

function afterEach(fn: HookFunction) {
  currentSuite().afterEach.push(fn)
}

function currentSuite() {
  return state.suiteStack[state.suiteStack.length - 1]
}

function newSuite(name?: string): SuiteContext {
  return { name, beforeEach: [], afterEach: [] }
}

function expect(actual: unknown) {
  return {
    toBe(expected: unknown) {
      if (!Object.is(actual, expected)) {
        throw assertionError(`Expected ${format(actual)} to be ${format(expected)}`, expected, actual)
      }
    },

    toEqual(expected: unknown) {
      if (!deepEqual(actual, expected)) {
        throw assertionError(`Expected ${format(actual)} to equal ${format(expected)}`, expected, actual)
      }
    },

    toContain(expected: unknown) {
      const ok =
        typeof actual === 'string'
          ? actual.includes(String(expected))
          : Array.isArray(actual) && actual.includes(expected)

      if (!ok) {
        throw assertionError(`Expected ${format(actual)} to contain ${format(expected)}`, expected, actual)
      }
    },

    toThrow(expected?: string | RegExp) {
      if (typeof actual !== 'function') {
        throw assertionError(`Expected ${format(actual)} to be a function`, 'function', typeof actual)
      }

      let thrown: unknown

      try {
        ;(actual as () => unknown)()
      } catch (error) {
        thrown = error
      }

      if (thrown === undefined) {
        throw assertionError('Expected function to throw', expected, undefined)
      }

      if (expected !== undefined) {
        const message = thrown instanceof Error ? thrown.message : String(thrown)
        const matches =
          expected instanceof RegExp ? expected.test(message) : message.includes(String(expected))

        if (!matches) {
          throw assertionError(
            `Expected thrown message ${format(message)} to match ${format(expected)}`,
            expected,
            message
          )
        }
      }
    }
  }
}

async function __voltRunTestModule(code: string, file: string) {
  reset()
  ;(0, eval)(`${code}\n//# sourceURL=${file}`)

  const results: TestResult[] = []
  const startedAt = Date.now()

  for (const registered of state.tests) {
    const testStartedAt = Date.now()

    try {
      for (const hook of registered.beforeEach) await hook()
      await registered.fn()
      results.push(result(registered, 'passed', testStartedAt))
    } catch (error) {
      results.push(result(registered, 'failed', testStartedAt, serializeError(error)))
    } finally {
      for (const hook of registered.afterEach) await hook()
    }
  }

  const failed = results.filter((item) => item.status === 'failed').length

  return {
    file,
    status: failed === 0 ? 'passed' : 'failed',
    duration: Date.now() - startedAt,
    total: results.length,
    failed,
    tests: results
  }
}

function result(
  registered: RegisteredTest,
  status: 'passed' | 'failed',
  startedAt: number,
  error?: SerializedError
): TestResult {
  return {
    id: registered.id,
    name: registered.name,
    fullName: [...registered.suite, registered.name].join(' › '),
    status,
    duration: Date.now() - startedAt,
    ...(error ? { error } : {})
  }
}

function assertionError(message: string, expected: unknown, actual: unknown) {
  const error = new Error(message) as Error & { expected?: unknown; actual?: unknown }
  error.name = 'AssertionError'
  error.expected = expected
  error.actual = actual
  return error
}

function serializeError(error: unknown): SerializedError {
  if (error instanceof Error) {
    const details = error as Error & { expected?: unknown; actual?: unknown }

    return {
      name: error.name,
      message: error.message,
      ...(error.stack ? { stack: error.stack } : {}),
      ...('expected' in details ? { expected: details.expected } : {}),
      ...('actual' in details ? { actual: details.actual } : {})
    }
  }

  return { name: 'Error', message: String(error) }
}

function deepEqual(left: unknown, right: unknown): boolean {
  if (Object.is(left, right)) return true

  if (typeof left !== typeof right) return false

  if (typeof left !== 'object' || left === null || right === null) {
    return false
  }

  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right)) return false
    if (left.length !== right.length) return false
    return left.every((value, index) => deepEqual(value, right[index]))
  }

  const leftRecord = left as Record<string, unknown>
  const rightRecord = right as Record<string, unknown>
  const leftKeys = Object.keys(leftRecord)
  const rightKeys = Object.keys(rightRecord)

  if (leftKeys.length !== rightKeys.length) return false

  return leftKeys.every((key) =>
    Object.prototype.hasOwnProperty.call(rightRecord, key) && deepEqual(leftRecord[key], rightRecord[key])
  )
}

function format(value: unknown) {
  if (typeof value === 'string') return JSON.stringify(value)

  try {
    return JSON.stringify(value)
  } catch {
    return String(value)
  }
}

Object.assign(globalThis, {
  describe,
  test,
  it: test,
  beforeEach,
  afterEach,
  expect,
  __voltRunTestModule
})
