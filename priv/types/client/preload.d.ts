declare global {
  var __voltPreload:
    | ((load: () => Promise<unknown>, deps: string[]) => Promise<unknown>)
    | undefined
}

export {}
