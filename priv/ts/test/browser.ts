import './core'

type BrowserPayload = {
  testCode: string
  file: string
  mode: 'collect' | 'run'
  testId?: number | null
}

async function executeBrowserTest(payload: BrowserPayload) {
  if (payload.mode === 'collect') {
    return globalThis.__voltCollectTestModule(payload.testCode, payload.file)
  }

  if (payload.testId === null || payload.testId === undefined) {
    return globalThis.__voltRunTestModule(payload.testCode, payload.file)
  }

  return globalThis.__voltRunTestModule(payload.testCode, payload.file, payload.testId)
}

Object.assign(globalThis, { __voltExecuteBrowserTest: executeBrowserTest })
