declare global {
  function __voltCollectTestModule(code: string, file: string): Promise<Volt.Test.Metadata[]>
  function __voltCollectLoadedTestModule(
    loader: () => Promise<unknown>,
    file: string
  ): Promise<Volt.Test.Metadata[]>
  function __voltRunTestModule(code: string, file: string, onlyId?: number): Promise<Volt.Test.FileResult>
  function __voltRunLoadedTestModule(
    loader: () => Promise<unknown>,
    file: string,
    onlyId?: number
  ): Promise<Volt.Test.FileResult>

  var __voltBrowserTestCode: string | undefined

  var __voltExecuteBrowserTest:
    | ((payload: {
        testCode?: string
        testUrl?: string
        file: string
        mode: 'collect' | 'run'
        testId?: number | null
      }) => Promise<Volt.Test.Metadata[] | Volt.Test.FileResult>)
    | undefined
}

export {}
