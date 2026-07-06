function assert(value, message) {
  if (!value) {
    throw new Error(message || 'assertion failed')
  }
}

assert.ok = assert
assert.equal = (left, right, message) => {
  if (left != right) {
    throw new Error(message || `assert.equal: ${left} != ${right}`)
  }
}
assert.strictEqual = (left, right, message) => {
  if (left !== right) {
    throw new Error(message || `assert.strictEqual: ${left} !== ${right}`)
  }
}

module.exports = assert
module.exports.default = assert
