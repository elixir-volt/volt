declare namespace Volt {
  namespace Test {
    type Awaitable<T> = T | PromiseLike<T>
    type Mode = 'run' | 'skip' | 'todo'

    interface Options {
      skip?: boolean | string
      todo?: boolean | string
      tags?: string[]
    }

    interface Metadata {
      id: number
      name: string
      fullName: string
      suite: string[]
      mode: Mode
      skipReason?: string
      tags: string[]
    }

    interface Context {
      task: Metadata
      expect: Expect
      skip(note?: string): never
      skip(condition: boolean, note?: string): void
    }

    type Fn = (context: Context) => Awaitable<unknown>
    type Hook = () => Awaitable<unknown>

    interface API {
      (name: string, fn?: Fn): void
      (name: string, options: Options, fn?: Fn): void
      skip: API
      todo: API
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

    interface Expect {
      (actual: unknown): Matchers
    }

    type Status = 'passed' | 'failed' | 'skipped'

    interface SerializedError {
      name: string
      message: string
      stack?: string
      expected?: unknown
      actual?: unknown
    }

    interface Registered {
      id: number
      name: string
      suite: string[]
      beforeEach: Hook[]
      afterEach: Hook[]
      fn?: Fn
      mode: Mode
      skipReason?: string
      tags: string[]
    }

    interface Result {
      id: number
      name: string
      fullName: string
      status: Status
      duration: number
      error?: SerializedError
      skipReason?: string
    }

    interface Suite {
      name?: string
      beforeEach: Hook[]
      afterEach: Hook[]
    }

    interface State {
      tests: Registered[]
      suite: string[]
      suiteStack: Suite[]
      nextId: number
    }
  }
}

declare module 'volt:test' {
  export type Awaitable<T> = Volt.Test.Awaitable<T>
  export type TestMode = Volt.Test.Mode
  export type TestOptions = Volt.Test.Options
  export type TestTask = Volt.Test.Metadata
  export type TestContext = Volt.Test.Context
  export type TestFunction = Volt.Test.Fn
  export type HookFunction = Volt.Test.Hook
  export type TestAPI = Volt.Test.API
  export type Matchers = Volt.Test.Matchers
  export type ExpectStatic = Volt.Test.Expect

  export const describe: (name: string, fn: () => void) => void
  export const test: Volt.Test.API
  export const it: Volt.Test.API
  export const beforeEach: (fn: Volt.Test.Hook) => void
  export const afterEach: (fn: Volt.Test.Hook) => void
  export const expect: Volt.Test.Expect
}
