declare global {
  function __voltCollectTestModule(code: string, file: string): Promise<Volt.Test.Metadata[]>
  function __voltRunTestModule(code: string, file: string, onlyId?: number): Promise<Volt.Test.FileResult>

  var __voltExecuteBrowserTest:
    | ((payload: {
        testCode: string
        file: string
        mode: 'collect' | 'run'
        testId?: number | null
      }) => Promise<Volt.Test.Metadata[] | Volt.Test.FileResult>)
    | undefined
}

export {}
