import { ResultError } from '@exnota/lib/result'
import { HttpException, HttpStatus } from '@nestjs/common'

function httpException<V>(
  status: HttpStatus,
  details: {
    message: string
    error?: Error
  },
  code?: V,
): HttpException
function httpException<U, V>(
  status: HttpStatus,
  result: ResultError<U>,
  code?: V,
): HttpException
function httpException<U, V>(
  status: HttpStatus,
  detailsOrResult: { message: string; error?: Error } | ResultError<U>,
  code?: V,
) {
  if ('ok' in detailsOrResult) {
    return new HttpException(
      { message: detailsOrResult.message, code },
      status,
      {
        cause: detailsOrResult.error,
      },
    )
  }
  return new HttpException({ message: detailsOrResult.message, code }, status, {
    cause: detailsOrResult.error,
  })
}

export { httpException }
