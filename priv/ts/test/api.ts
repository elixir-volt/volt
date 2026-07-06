import { currentSuite, inheritedOptions, newSuite, state } from './state'
import { format } from './format'

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

  Object.assign(api, {
    each: createDescribeEach(defaultOptions)
  })

  if (chainable) {
    Object.assign(api, {
      skip: createDescribeAPI({ ...defaultOptions, skip: true }, false),
      todo: createDescribeAPI({ ...defaultOptions, todo: true }, false)
    })
  }

  return api as Volt.Test.DescribeAPI
}

function createDescribeEach(defaultOptions: Volt.Test.Options) {
  return (cases: readonly unknown[]) => (name: string, fn: (...args: unknown[]) => void) => {
    for (const [index, row] of cases.entries()) {
      const args = caseArgs(row)
      createDescribeAPI(defaultOptions, false)(formatCaseName(name, args, index), () => fn(...args))
    }
  }
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

  Object.assign(api, {
    each: createTestEach(defaultOptions)
  })

  if (chainable) {
    Object.assign(api, {
      skip: createTestAPI({ ...defaultOptions, skip: true }, false),
      todo: createTestAPI({ ...defaultOptions, todo: true }, false)
    })
  }

  return api as Volt.Test.API
}

function createTestEach(defaultOptions: Volt.Test.Options) {
  return (cases: readonly unknown[]) =>
    (
      name: string,
      fnOrOptions?: Volt.Test.EachFn | Volt.Test.Options,
      maybeFn?: Volt.Test.EachFn
    ) => {
      const options =
        typeof fnOrOptions === 'function' ? defaultOptions : { ...defaultOptions, ...fnOrOptions }
      const fn = typeof fnOrOptions === 'function' ? fnOrOptions : maybeFn

      for (const [index, row] of cases.entries()) {
        const args = caseArgs(row)
        registerTest(formatCaseName(name, args, index), options, (context) =>
          fn?.(...args, context)
        )
      }
    }
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

function caseArgs(row: unknown) {
  return Array.isArray(row) ? row : [row]
}

function formatCaseName(name: string, args: unknown[], index: number) {
  let argIndex = 0
  const formatted = name.replace(/%[sdifjo]/g, (token) => {
    const value = args[argIndex++]

    switch (token) {
      case '%d':
      case '%i':
      case '%f':
        return String(Number(value))
      case '%j':
      case '%o':
        return format(value)
      default:
        return String(value)
    }
  })

  return argIndex === 0 ? `${name} #${index + 1}` : formatted
}

export function beforeEach(fn: Volt.Test.Hook) {
  currentSuite().beforeEach.push(fn)
}

export function afterEach(fn: Volt.Test.Hook) {
  currentSuite().afterEach.push(fn)
}
