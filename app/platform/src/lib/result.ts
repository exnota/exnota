type ResultOk<T> = {
  readonly ok: true
  readonly value: T
}

type ResultError = {
  readonly ok: false
  readonly error: Error
  readonly message: string
}

type Result<T> = ResultOk<T> | ResultError

function resultOk<T>(value: T): Result<T> {
  return {
    ok: true,
    value,
  }
}

function resultError<T>(message: string, error?: Error): Result<T> {
  return {
    ok: false,
    message,
    error: error ?? new Error('Result error'),
  }
}

function isResultOk<T>(result: Result<T>): result is ResultOk<T> {
  return result.ok
}

function isResultError<T>(result: Result<T>): result is ResultError {
  return !result.ok
}

type Results<T> = {
  readonly values: (T | undefined)[]
  readonly okValues: T[]
  readonly firstErrorResult: ResultError | undefined
  withOnlyFirstError: <U = T>() => Results<U>
}

function assertResultError<T>(
  result: Result<T>,
): asserts result is ResultError {
  if (result.ok) {
    throw new Error('Not a ResultError')
  }
}

function assertResultOk<T>(result: Result<T>): asserts result is ResultOk<T> {
  if (!result.ok) {
    throw new Error('Not a ResultOk')
  }
}

export type { Result, ResultError, ResultOk, Results }
export {
  resultOk,
  resultError,
  isResultOk,
  isResultError,
  assertResultError,
  assertResultOk,
}
