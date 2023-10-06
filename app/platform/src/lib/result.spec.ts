import {
  Result,
  assertResultError,
  assertResultOk,
  isResultError,
  isResultOk,
  resultError,
  resultOk,
} from '@exnota/lib/result'

interface OkType {
  cat: string
}

describe('Result', () => {
  describe('Given an ok Result', () => {
    let result: Result<OkType>
    let value: OkType
    beforeEach(() => {
      value = { cat: 'dog' }
      result = resultOk(value)
    })
    describe('When resultOk is called', () => {
      test('Then it returns the expected values', () => {
        expect(result.ok).toBe(true)
        assertResultOk(result)
        expect(result.value).toBe(value)
      })
    })
  })
  describe('Given an error Result', () => {
    describe('When resultError is called', () => {
      describe('And only a message is provided', () => {
        let result: Result<string>
        beforeEach(() => {
          result = resultError('an error message')
        })
        test('Then it returns the expected values', () => {
          expect(result.ok).toBe(false)
          assertResultError(result)
          expect(result.message).toBe('an error message')
          expect(result.error).toEqual(new Error('Result error'))
        })
      })
      describe('And an Error is provided', () => {
        let result: Result<string>
        let error: Error
        beforeEach(() => {
          error = new Error('an error')
          result = resultError('an error message', error)
        })
        test('Then it returns the expected values', () => {
          expect(result.ok).toBe(false)
          assertResultError(result)
          expect(result.error).toBe(error)
        })
      })
    })
  })
})
describe('isResultOk', () => {
  describe('Given an ok result', () => {
    test('Then it returns true', () => {
      const ok = resultOk('result')
      expect(isResultOk(ok)).toBe(true)
    })
  })
  describe('Given an error result', () => {
    test('Then it returns false', () => {
      const err = resultError<string>('error')
      expect(isResultOk(err)).toBe(false)
    })
  })
})
describe('isResultError', () => {
  describe('Given an error result', () => {
    test('Then it returns true', () => {
      const err = resultError<string>('error')
      expect(isResultError(err)).toBe(true)
    })
  })
  describe('Given an ok result', () => {
    test('Then it returns false', () => {
      const ok = resultOk('result')
      expect(isResultError(ok)).toBe(false)
    })
  })
})
