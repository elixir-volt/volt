import './core'

type BrowserPayload = {
  testCode?: string
  testUrl?: string
  file: string
  mode: 'collect' | 'run'
  testId?: number | null
}

async function executeBrowserTest(payload: BrowserPayload) {
  const loader = moduleLoader(payload)

  if (payload.mode === 'collect') {
    if (loader) return globalThis.__voltCollectLoadedTestModule(loader, payload.file)
    return globalThis.__voltCollectTestModule(testCode(payload), payload.file)
  }

  if (payload.testId === null || payload.testId === undefined) {
    if (loader) return globalThis.__voltRunLoadedTestModule(loader, payload.file)
    return globalThis.__voltRunTestModule(testCode(payload), payload.file)
  }

  if (loader) return globalThis.__voltRunLoadedTestModule(loader, payload.file, payload.testId)
  return globalThis.__voltRunTestModule(testCode(payload), payload.file, payload.testId)
}

function moduleLoader(payload: BrowserPayload): (() => Promise<unknown>) | undefined {
  if (!payload.testUrl) return undefined
  return () => loadScript(`${payload.testUrl}?volt_test=${Date.now()}_${Math.random()}`)
}

function loadScript(src: string) {
  return new Promise<void>((resolve, reject) => {
    const script = document.createElement('script')
    script.src = src
    script.onload = () => {
      script.remove()
      resolve()
    }
    script.onerror = () => {
      script.remove()
      reject(new Error(`Failed to load Volt browser test module: ${src}`))
    }
    document.head.appendChild(script)
  })
}

function testCode(payload: BrowserPayload) {
  const code = payload.testCode ?? globalThis.__voltBrowserTestCode

  if (typeof code !== 'string') {
    throw new Error('Volt browser test code was not installed')
  }

  return code
}

Object.assign(globalThis, { __voltExecuteBrowserTest: executeBrowserTest })
