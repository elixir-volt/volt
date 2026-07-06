declare namespace VoltTest {
  type Awaitable<T> = T | PromiseLike<T>
  type TestMode = 'run' | 'skip' | 'todo'

  interface TestOptions {
    skip?: boolean | string
    todo?: boolean | string
    tags?: string[]
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

  interface TestContext {
    task: TestMetadata
    expect: ExpectStatic
    skip(note?: string): never
    skip(condition: boolean, note?: string): void
  }

  type TestFunction = (context: TestContext) => Awaitable<unknown>
  type HookFunction = () => Awaitable<unknown>

  interface TestAPI {
    (name: string, fn?: TestFunction): void
    (name: string, options: TestOptions, fn?: TestFunction): void
    skip: TestAPI
    todo: TestAPI
  }

  interface Matchers {
    readonly not: Matchers
    toBe(expected: unknown): void
    toEqual(expected: unknown): void
    toContain(expected: unknown): void
    toBeDefined(): void
    toBeUndefined(): void
    toBeTruthy(): void
    toBeFalsy(): void
    toBeNull(): void
    toBeNaN(): void
    toBeCloseTo(expected: number, digits?: number): void
    toThrow(expected?: string | RegExp): void
  }

  interface ExpectStatic {
    (actual: unknown): Matchers
  }

  type TestStatus = 'passed' | 'failed' | 'skipped'

  interface SerializedError {
    name: string
    message: string
    stack?: string
    expected?: unknown
    actual?: unknown
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

  interface TestResult {
    id: number
    name: string
    fullName: string
    status: TestStatus
    duration: number
    error?: SerializedError
    skipReason?: string
  }

  interface SuiteContext {
    name?: string
    beforeEach: HookFunction[]
    afterEach: HookFunction[]
  }

  interface State {
    tests: RegisteredTest[]
    suite: string[]
    suiteStack: SuiteContext[]
    nextId: number
  }
}

declare module 'volt:test' {
  export type Awaitable<T> = VoltTest.Awaitable<T>
  export type TestMode = VoltTest.TestMode
  export type TestOptions = VoltTest.TestOptions
  export type TestTask = VoltTest.TestMetadata
  export type TestContext = VoltTest.TestContext
  export type TestFunction = VoltTest.TestFunction
  export type HookFunction = VoltTest.HookFunction
  export type TestAPI = VoltTest.TestAPI
  export type Matchers = VoltTest.Matchers
  export type ExpectStatic = VoltTest.ExpectStatic

  export const describe: (name: string, fn: () => void) => void
  export const test: VoltTest.TestAPI
  export const it: VoltTest.TestAPI
  export const beforeEach: (fn: VoltTest.HookFunction) => void
  export const afterEach: (fn: VoltTest.HookFunction) => void
  export const expect: VoltTest.ExpectStatic
}
