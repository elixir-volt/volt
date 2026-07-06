import { afterEach, beforeEach, describe, it, test } from './api'
import { expect } from './matchers'
import { __voltCollectTestModule, __voltRunTestModule } from './runner'

Object.assign(globalThis, {
  describe,
  test,
  it,
  beforeEach,
  afterEach,
  expect,
  __voltCollectTestModule,
  __voltRunTestModule
})
