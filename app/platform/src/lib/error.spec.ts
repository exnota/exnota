import { HttpException, HttpStatus } from '@nestjs/common'
import { httpException } from './error'
import { assertResultError, resultError } from './result'

describe('httpException', () => {
  describe('when an error result is provided', () => {
    describe('and a code is provided', () => {
      it('should return a HttpException', () => {
        const result = resultError(
          'result error',
          'result message',
          new Error('result error object'),
        )
        assertResultError(result)
        const expected = new HttpException(
          { message: 'result message', code: 'some code' },
          500,
          {
            cause: result.error,
          },
        )

        const actual = httpException(
          HttpStatus.INTERNAL_SERVER_ERROR,
          result,
          'some code',
        )
        expect(actual.cause).toEqual(expected.cause)
        expect(actual.getResponse()).toEqual(expected.getResponse())
        expect(actual.getStatus()).toEqual(expected.getStatus())
        expect(actual.message).toEqual(expected.message)
        expect(actual.name).toEqual(expected.name)
      })
    })
    describe('and no code is provided', () => {
      it('should return a HttpException', () => {
        const result = resultError(
          'some error',
          'some message',
          new Error('some error object'),
        )
        assertResultError(result)
        const expected = new HttpException({ message: 'some message' }, 500, {
          cause: result.error,
        })

        const actual = httpException(HttpStatus.INTERNAL_SERVER_ERROR, result)
        expect(actual.cause).toEqual(expected.cause)
        expect(actual.getResponse()).toEqual(expected.getResponse())
        expect(actual.getStatus()).toEqual(expected.getStatus())
        expect(actual.message).toEqual(expected.message)
        expect(actual.name).toEqual(expected.name)
      })
    })
  })
  describe('when error details are provided', () => {
    describe('and all optional properties are provided', () => {
      it('should return a HttpException', () => {
        const error = new Error('some error object')
        const expected = new HttpException(
          { message: 'some error', code: 'some code' },
          500,
          {
            cause: error,
          },
        )

        const actual = httpException(
          HttpStatus.INTERNAL_SERVER_ERROR,
          {
            message: 'some error',
            error,
          },
          'some code',
        )
        expect(actual.cause).toEqual(expected.cause)
        expect(actual.getResponse()).toEqual(expected.getResponse())
        expect(actual.getStatus()).toEqual(expected.getStatus())
        expect(actual.message).toEqual(expected.message)
        expect(actual.name).toEqual(expected.name)
      })
    })
    describe('and no code is provided', () => {
      it('should return a HttpException', () => {
        const expected = new HttpException({ message: 'some error' }, 500)

        const actual = httpException(HttpStatus.INTERNAL_SERVER_ERROR, {
          message: 'some error',
        })
        expect(actual.cause).toEqual(expected.cause)
        expect(actual.getResponse()).toEqual(expected.getResponse())
        expect(actual.getStatus()).toEqual(expected.getStatus())
        expect(actual.message).toEqual(expected.message)
        expect(actual.name).toEqual(expected.name)
      })
    })
  })
})
