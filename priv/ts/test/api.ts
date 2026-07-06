import { currentSuite, inheritedOptions, newSuite, state } from './state'

export const test = createTestAPI()
export const it = test
export const describe = createDescribeAPI()

function createDescribeAPI(defaultOptions: Volt.Test.Options = {}, chainable = true) {
  const api = (name: string, fn: () => void) => {
    state.suite.push(name)
    state.suiteStack.push(newSuite(name, defaultOptions))

    try {
      fn()
    } finally {
      state.suiteStack.pop()
      state.suite.pop()
    }
  }

  if (chainable) {
    Object.assign(api, {
      skip: createDescribeAPI({ ...defaultOptions, skip: true }, false),
      todo: createDescribeAPI({ ...defaultOptions, todo: true }, false)
    })
  }

  return api as Volt.Test.DescribeAPI
}

function createTestAPI(defaultOptions: Volt.Test.Options = {}, chainable = true) {
  const api = (
    name: string,
    optionsOrFn?: Volt.Test.Options | Volt.Test.Fn,
    maybeFn?: Volt.Test.Fn
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

  return api as Volt.Test.API
}

function normalizeTestArgs(
  defaultOptions: Volt.Test.Options,
  optionsOrFn?: Volt.Test.Options | Volt.Test.Fn,
  maybeFn?: Volt.Test.Fn
) {
  if (typeof optionsOrFn === 'function') {
    return { options: defaultOptions, fn: optionsOrFn }
  }

  return {
    options: { ...defaultOptions, ...optionsOrFn },
    fn: maybeFn
  }
}

function registerTest(name: string, options: Volt.Test.Options, fn?: Volt.Test.Fn) {
  options = { ...inheritedOptions(), ...options }
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

function testMode(options: Volt.Test.Options, fn?: Volt.Test.Fn): Volt.Test.Mode {
  if (truthyOption(options.skip)) return 'skip'
  if (truthyOption(options.todo) || fn === undefined) return 'todo'
  return 'run'
}

function truthyOption(value: unknown) {
  return value === true || typeof value === 'string'
}

function skipReason(options: Volt.Test.Options, mode: Volt.Test.Mode) {
  if (mode === 'skip') return typeof options.skip === 'string' ? options.skip : 'Skipped'
  if (mode === 'todo') return typeof options.todo === 'string' ? options.todo : 'TODO'
  return undefined
}

export function beforeEach(fn: Volt.Test.Hook) {
  currentSuite().beforeEach.push(fn)
}

export function afterEach(fn: Volt.Test.Hook) {
  currentSuite().afterEach.push(fn)
}
