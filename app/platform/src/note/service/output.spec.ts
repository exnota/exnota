import { isTranscriptionOutput } from './output'

describe('TranscriptionOutput', () => {
  describe('When argument has no transcriptions', () => {
    it('should return true', () => {
      expect(
        isTranscriptionOutput({
          transcription: [],
        }),
      ).toEqual(true)
    })
  })
  describe('When argument has one transcription', () => {
    describe('and no additional properties on objects', () => {
      it('should return true', () => {
        expect(
          isTranscriptionOutput({
            transcription: [
              {
                text: 'some text',
              },
            ],
          }),
        ).toEqual(true)
      })
    })
    describe('and there exists additional properties on objects', () => {
      it('should return true', () => {
        expect(
          isTranscriptionOutput({
            otherProp: 5,
            transcription: [
              {
                text: 'some text',
                otherProp: 'other prop text',
              },
            ],
          }),
        ).toEqual(true)
      })
    })
  })
  describe('When argument has multiple transcriptions', () => {
    it('should return true', () => {
      expect(
        isTranscriptionOutput({
          transcription: [
            {
              text: 'some text',
            },
            {
              text: 'some more text',
            },
          ],
        }),
      ).toEqual(true)
    })
  })

  describe('When argument is not an object', () => {
    it('should return false', () => {
      expect(isTranscriptionOutput(null)).toEqual(false)
      expect(isTranscriptionOutput(5)).toEqual(false)
      expect(isTranscriptionOutput(undefined)).toEqual(false)
      expect(isTranscriptionOutput(() => {})).toEqual(false)
    })
  })
  describe('When argument is an empty object', () => {
    it('should return false', () => {
      expect(isTranscriptionOutput({})).toEqual(false)
    })
  })
  describe('When transcription property is not an array', () => {
    it('should return false', () => {
      expect(isTranscriptionOutput({ transcription: 5 })).toEqual(false)
      expect(isTranscriptionOutput({ transcription: null })).toEqual(false)
      expect(isTranscriptionOutput({ transcription: {} })).toEqual(false)
    })
  })
  describe('When transcription property contains an array item without a text property', () => {
    it('should return false', () => {
      expect(
        isTranscriptionOutput({ transcription: [{ text: 'text' }, {}] }),
      ).toEqual(false)
      expect(isTranscriptionOutput({ transcription: [{}] })).toEqual(false)
      expect(
        isTranscriptionOutput({ transcription: [{ text: undefined }] }),
      ).toEqual(false)
    })
  })
})
