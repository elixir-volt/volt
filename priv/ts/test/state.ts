export const state: Volt.Test.State = {
  tests: [],
  suite: [],
  suiteStack: [newSuite()],
  nextId: 1
}

export function reset() {
  state.tests = []
  state.suite = []
  state.suiteStack = [newSuite()]
  state.nextId = 1
}

export function currentSuite() {
  return state.suiteStack[state.suiteStack.length - 1]
}

export function newSuite(name?: string, options: Volt.Test.Options = {}): Volt.Test.Suite {
  return { name, options, beforeEach: [], afterEach: [] }
}

export function inheritedOptions() {
  return state.suiteStack.reduce<Volt.Test.Options>(
    (options, suite) => ({ ...options, ...suite.options }),
    {}
  )
}
