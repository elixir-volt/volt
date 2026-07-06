class SkipError extends Error {
  constructor(readonly reason?: string) {
    super(reason || 'Skipped')
    this.name = 'SkipError'
  }
}

const state: VoltTest.State = {
  tests: [],
  suite: [],
  suiteStack: [newSuite()],
  nextId: 1
}

const test = createTestAPI()
const it = test

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

function createTestAPI(defaultOptions: VoltTest.TestOptions = {}, chainable = true) {
  const api = (
    name: string,
    optionsOrFn?: VoltTest.TestOptions | VoltTest.TestFunction,
    maybeFn?: VoltTest.TestFunction
  ) => {
    const { options, fn } = normalizeTestArgs(defaultOptions, optionsOrFn, maybeFn)
    registerTest(name, options, fn)
  }

  if (chainable) {
    Object.assign(api, {
      skip: createTestAPI({ ...defaultOptions, skip: true }, false),
      todo: createTestAPI({ ...defaultOptions, todo: true }, false)
    })
  }

  return api as VoltTest.TestAPI
}

function normalizeTestArgs(
  defaultOptions: VoltTest.TestOptions,
  optionsOrFn?: VoltTest.TestOptions | VoltTest.TestFunction,
  maybeFn?: VoltTest.TestFunction
) {
  if (typeof optionsOrFn === 'function') {
    return { options: defaultOptions, fn: optionsOrFn }
  }

  return {
    options: { ...defaultOptions, ...(optionsOrFn || {}) },
    fn: maybeFn
  }
}

function registerTest(name: string, options: VoltTest.TestOptions, fn?: VoltTest.TestFunction) {
  const mode = testMode(options, fn)

  state.tests.push({
    id: state.nextId++,
    name,
    suite: [...state.suite],
    beforeEach: state.suiteStack.flatMap((suite) => suite.beforeEach),
    afterEach: state.suiteStack.flatMap((suite) => suite.afterEach).reverse(),
    fn,
    mode,
    skipReason: skipReason(options, mode),
    tags: Array.isArray(options.tags) ? options.tags.map(String) : []
  })
}

function testMode(options: VoltTest.TestOptions, fn?: VoltTest.TestFunction): VoltTest.TestMode {
  if (truthyOption(options.skip)) return 'skip'
  if (truthyOption(options.todo) || fn === undefined) return 'todo'
  return 'run'
}

function truthyOption(value: unknown) {
  return value === true || typeof value === 'string'
}

function skipReason(options: VoltTest.TestOptions, mode: VoltTest.TestMode) {
  if (mode === 'skip') return typeof options.skip === 'string' ? options.skip : 'Skipped'
  if (mode === 'todo') return typeof options.todo === 'string' ? options.todo : 'TODO'
  return undefined
}

function beforeEach(fn: VoltTest.HookFunction) {
  currentSuite().beforeEach.push(fn)
}

function afterEach(fn: VoltTest.HookFunction) {
  currentSuite().afterEach.push(fn)
}

function currentSuite() {
  return state.suiteStack[state.suiteStack.length - 1]
}

function newSuite(name?: string): VoltTest.SuiteContext {
  return { name, beforeEach: [], afterEach: [] }
}

function expect(actual: unknown) {
  return createExpectation(actual, false)
}

function createExpectation(actual: unknown, negated: boolean): VoltTest.Matchers {
  const match = (ok: boolean, message: string, expected?: unknown) => {
    if (negated ? ok : !ok) {
      throw assertionError(message, expected, actual)
    }
  }

  const matchers: VoltTest.Matchers = {
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

async function __voltCollectTestModule(code: string, file: string) {
  loadTestModule(code, file)

  return state.tests.map(metadata)
}

async function __voltRunTestModule(code: string, file: string, onlyId?: number) {
  loadTestModule(code, file)

  const results: VoltTest.TestResult[] = []
  const startedAt = Date.now()
  const tests =
    onlyId === undefined ? state.tests : state.tests.filter((test) => test.id === onlyId)

  for (const registered of tests) {
    const testStartedAt = Date.now()

    if (registered.mode !== 'run') {
      results.push(result(registered, 'skipped', testStartedAt, undefined, registered.skipReason))
      continue
    }

    try {
      for (const hook of registered.beforeEach) await hook()
      await registered.fn!(contextFor(registered))
      results.push(result(registered, 'passed', testStartedAt))
    } catch (error) {
      if (error instanceof SkipError) {
        results.push(result(registered, 'skipped', testStartedAt, undefined, error.reason))
      } else {
        results.push(result(registered, 'failed', testStartedAt, serializeError(error)))
      }
    } finally {
      for (const hook of registered.afterEach) await hook()
    }
  }

  const failed = results.filter((item) => item.status === 'failed').length
  const skipped = results.filter((item) => item.status === 'skipped').length

  return {
    file,
    status: failed === 0 ? 'passed' : 'failed',
    duration: Date.now() - startedAt,
    total: results.length,
    failed,
    skipped,
    tests: results
  }
}

function loadTestModule(code: string, _file: string) {
  reset()
  ;(0, eval)(code)
}

function contextFor(registered: VoltTest.RegisteredTest): VoltTest.TestContext {
  return {
    task: metadata(registered),
    expect,
    skip(conditionOrNote?: boolean | string, note?: string) {
      if (conditionOrNote === false) return
      const reason = typeof conditionOrNote === 'string' ? conditionOrNote : note
      throw new SkipError(reason)
    }
  }
}

function metadata(registered: VoltTest.RegisteredTest): VoltTest.TestMetadata {
  return {
    id: registered.id,
    name: registered.name,
    fullName: fullName(registered),
    suite: registered.suite,
    mode: registered.mode,
    ...(registered.skipReason ? { skipReason: registered.skipReason } : {}),
    tags: registered.tags
  }
}

function result(
  registered: VoltTest.RegisteredTest,
  status: 'passed' | 'failed' | 'skipped',
  startedAt: number,
  error?: VoltTest.SerializedError,
  skipReason?: string
): VoltTest.TestResult {
  return {
    id: registered.id,
    name: registered.name,
    fullName: fullName(registered),
    status,
    duration: Date.now() - startedAt,
    ...(error ? { error } : {}),
    ...(skipReason ? { skipReason } : {})
  }
}

function fullName(registered: VoltTest.RegisteredTest) {
  return [...registered.suite, registered.name].join(' › ')
}

function assertionError(message: string, expected: unknown, actual: unknown) {
  const error = new Error(message) as Error & { expected?: unknown; actual?: unknown }
  error.name = 'AssertionError'
  error.expected = expected
  error.actual = actual
  return error
}

function serializeError(error: unknown): VoltTest.SerializedError {
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

  return leftKeys.every(
    (key) =>
      Object.prototype.hasOwnProperty.call(rightRecord, key) &&
      deepEqual(leftRecord[key], rightRecord[key])
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
  it,
  beforeEach,
  afterEach,
  expect,
  __voltCollectTestModule,
  __voltRunTestModule
})
