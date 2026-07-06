// Fallback for bundled CommonJS internals that still call require() at runtime.
// OXC/Rolldown should ideally lower these fully, but some packages keep
// builtin requires such as require('assert') in generated code.
const __voltGlobals = globalThis

const __voltAssert = (value, message) => {
  if (!value) throw new Error(message || 'assertion failed')
}
__voltAssert.ok = __voltAssert
__voltAssert.equal = (left, right, message) => {
  // oxlint-disable-next-line eqeqeq -- assert.equal intentionally uses loose equality.
  if (left != right) throw new Error(message || `assert.equal: ${left} != ${right}`)
}
__voltAssert.strictEqual = (left, right, message) => {
  if (left !== right) throw new Error(message || `assert.strictEqual: ${left} !== ${right}`)
}

__voltGlobals.require = (name) => {
  if (name === 'assert' || name === 'node:assert') return __voltAssert

  const builtin = __voltGlobals[name] ?? __voltGlobals[name.replace('node:', '')]
  if (builtin !== undefined) return builtin

  throw new Error(`require: module '${name}' not available`)
}
