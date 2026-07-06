import { afterEach, beforeEach, describe, it, test } from './api'
import { expect } from './matchers'
import {
  __voltCollectLoadedTestModule,
  __voltCollectTestModule,
  __voltRunLoadedTestModule,
  __voltRunTestModule
} from './runner'

Object.assign(globalThis, {
  describe,
  test,
  it,
  beforeEach,
  afterEach,
  expect,
  __voltCollectLoadedTestModule,
  __voltCollectTestModule,
  __voltRunLoadedTestModule,
  __voltRunTestModule
})
