type TestFunction = (context: TestContext) => unknown | Promise<unknown>
type HookFunction = () => unknown | Promise<unknown>
type TestMode = 'run' | 'skip' | 'todo'

interface TestOptions {
  skip?: boolean | string
  todo?: boolean | string
  tags?: string[]
}

interface TestContext {
  task: TestMetadata
  expect: typeof expect
  skip: (conditionOrNote?: boolean | string, note?: string) => void
}

interface RegisteredTest {
  id: number
  name: string
  suite: string[]
  beforeEach: HookFunction[]
  afterEach: HookFunction[]
  fn?: TestFunction
  mode: TestMode
  skipReason?: string
  tags: string[]
}

interface SuiteContext {
  name?: string
  beforeEach: HookFunction[]
  afterEach: HookFunction[]
}

interface TestMetadata {
  id: number
  name: string
  fullName: string
  suite: string[]
  mode: TestMode
  skipReason?: string
  tags: string[]
}

interface TestResult {
  id: number
  name: string
  fullName: string
  status: 'passed' | 'failed' | 'skipped'
  duration: number
  error?: SerializedError
  skipReason?: string
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

class SkipError extends Error {
  constructor(readonly reason?: string) {
    super(reason || 'Skipped')
    this.name = 'SkipError'
  }
}

const state: VoltTestState = {
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

function createTestAPI(defaultOptions: TestOptions = {}, chainable = true) {
  const api = (name: string, optionsOrFn?: TestOptions | TestFunction, maybeFn?: TestFunction) => {
    const { options, fn } = normalizeTestArgs(defaultOptions, optionsOrFn, maybeFn)
    registerTest(name, options, fn)
  }

  if (chainable) {
    Object.assign(api, {
      skip: createTestAPI({ ...defaultOptions, skip: true }, false),
      todo: createTestAPI({ ...defaultOptions, todo: true }, false)
    })
  }

  return api as TestAPI
}

interface TestAPI {
  (name: string, fn?: TestFunction): void
  (name: string, options: TestOptions, fn?: TestFunction): void
  skip: TestAPI
  todo: TestAPI
}

function normalizeTestArgs(
  defaultOptions: TestOptions,
  optionsOrFn?: TestOptions | TestFunction,
  maybeFn?: TestFunction
) {
  if (typeof optionsOrFn === 'function') {
    return { options: defaultOptions, fn: optionsOrFn }
  }

  return {
    options: { ...defaultOptions, ...(optionsOrFn || {}) },
    fn: maybeFn
  }
}

function registerTest(name: string, options: TestOptions, fn?: TestFunction) {
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

function testMode(options: TestOptions, fn?: TestFunction): TestMode {
  if (truthyOption(options.skip)) return 'skip'
  if (truthyOption(options.todo) || fn === undefined) return 'todo'
  return 'run'
}

function truthyOption(value: unknown) {
  return value === true || typeof value === 'string'
}

function skipReason(options: TestOptions, mode: TestMode) {
  if (mode === 'skip') return typeof options.skip === 'string' ? options.skip : 'Skipped'
  if (mode === 'todo') return typeof options.todo === 'string' ? options.todo : 'TODO'
  return undefined
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

async function __voltCollectTestModule(code: string, file: string) {
  loadTestModule(code, file)

  return state.tests.map(metadata)
}

async function __voltRunTestModule(code: string, file: string, onlyId?: number) {
  loadTestModule(code, file)

  const results: TestResult[] = []
  const startedAt = Date.now()
  const tests = onlyId === undefined ? state.tests : state.tests.filter((test) => test.id === onlyId)

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

function contextFor(registered: RegisteredTest): TestContext {
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

function metadata(registered: RegisteredTest): TestMetadata {
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
  registered: RegisteredTest,
  status: 'passed' | 'failed' | 'skipped',
  startedAt: number,
  error?: SerializedError,
  skipReason?: string
): TestResult {
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

function fullName(registered: RegisteredTest) {
  return [...registered.suite, registered.name].join(' › ')
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
  it,
  beforeEach,
  afterEach,
  expect,
  __voltCollectTestModule,
  __voltRunTestModule
})
