import { SkipError, serializeError } from './errors'
import { expect } from './matchers'
import { reset, state } from './state'

export async function __voltCollectTestModule(code: string, file: string) {
  loadTestModule(code, file)

  return state.tests.map(metadata)
}

export async function __voltCollectLoadedTestModule(loader: () => Promise<unknown>, _file: string) {
  await loadBrowserTestModule(loader)

  return state.tests.map(metadata)
}

export async function __voltRunTestModule(code: string, file: string, onlyId?: number) {
  loadTestModule(code, file)

  return runLoadedTests(file, onlyId)
}

export async function __voltRunLoadedTestModule(
  loader: () => Promise<unknown>,
  file: string,
  onlyId?: number
) {
  await loadBrowserTestModule(loader)

  return runLoadedTests(file, onlyId)
}

async function runLoadedTests(file: string, onlyId?: number) {
  const results: Volt.Test.Result[] = []
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
      await runRegisteredTest(registered)
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

async function loadBrowserTestModule(loader: () => Promise<unknown>) {
  reset()
  await loader()
}

function runRegisteredTest(registered: Volt.Test.Registered) {
  if (!registered.fn) {
    throw new Error(`Missing test function for ${fullName(registered)}`)
  }

  return registered.fn(contextFor(registered))
}

function contextFor(registered: Volt.Test.Registered): Volt.Test.Context {
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

function metadata(registered: Volt.Test.Registered): Volt.Test.Metadata {
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
  registered: Volt.Test.Registered,
  status: 'passed' | 'failed' | 'skipped',
  startedAt: number,
  error?: Volt.Test.SerializedError,
  skipReason?: string
): Volt.Test.Result {
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

function fullName(registered: Volt.Test.Registered) {
  return [...registered.suite, registered.name].join(' › ')
}
