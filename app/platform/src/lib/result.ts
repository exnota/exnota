type ResultOk<T> = {
  readonly ok: true
  readonly value: T
}

type ResultError<U> = {
  readonly ok: false
  readonly type: U
  readonly error: Error
  readonly message: string
}

type Result<T, U> = ResultOk<T> | ResultError<U>

function resultOk<T, U>(value: T): Result<T, U> {
  return {
    ok: true,
    value,
  }
}

function resultError<T, U>(
  type: U,
  message: string,
  error?: Error,
): Result<T, U> {
  return {
    ok: false,
    type,
    message,
    error: error ?? new Error('Result error'),
  }
}

function mapErrorType<T, U>(
  type: U,
  errorResult: ResultError<T>,
): ResultError<U> {
  return {
    ok: false,
    type,
    message: errorResult.message,
    error: errorResult.error,
  }
}

function isResultOk<T, U>(result: Result<T, U>): result is ResultOk<T> {
  return result.ok
}

function isResultError<T, U>(result: Result<T, U>): result is ResultError<U> {
  return !result.ok
}

type Results<T, U> = {
  readonly values: (T | undefined)[]
  readonly okValues: T[]
  readonly firstErrorResult: ResultError<U> | undefined
  withOnlyFirstError: <V = T>() => Results<V, U>
}

function assertResultError<T, U>(
  result: Result<T, U>,
): asserts result is ResultError<U> {
  if (result.ok) {
    throw new Error('Not a ResultError')
  }
}

function assertResultOk<T, U>(
  result: Result<T, U>,
): asserts result is ResultOk<T> {
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
  mapErrorType,
}
