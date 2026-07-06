export class SkipError extends Error {
  constructor(readonly reason?: string) {
    super(reason || 'Skipped')
    this.name = 'SkipError'
  }
}

export function assertionError(message: string, expected: unknown, actual: unknown) {
  const error = new Error(message) as Error & { expected?: unknown; actual?: unknown }
  error.name = 'AssertionError'
  error.expected = expected
  error.actual = actual
  return error
}

export function serializeError(error: unknown): Volt.Test.SerializedError {
  if (error instanceof Error) {
    const details = error as Error & { expected?: unknown; actual?: unknown }

    return {
      name: error.name,
      message: error.message,
      ...(error.stack ? { stack: error.stack } : {}),
      ...('expected' in details ? { expected: details.expected } : {}),
      ...('actual' in details ? { actual: details.actual } : {})
    }
  }

  return { name: 'Error', message: String(error) }
}
