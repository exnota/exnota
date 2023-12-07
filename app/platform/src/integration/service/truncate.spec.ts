import {
  chunkTranscription,
  truncateTranscription,
} from '@exnota/integration/service/truncate'

describe('truncateTranscription', () => {
  describe('Given a transcription less than the min', () => {
    describe('and there is no period', () => {
      it('should return the transcription untruncated', () => {
        expect(truncateTranscription('some transcription')).toEqual(
          'some transcription',
        )
      })
    })
    describe('and there are multiple periods', () => {
      it('should return the transcription untruncated', () => {
        expect(truncateTranscription('some. kinda. transcription.')).toEqual(
          'some. kinda. transcription.',
        )
      })
    })
  })
  describe('Given a transcription equal to the min', () => {
    describe('and it ends with a period', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription exactly fifty characters loong.'

        // Verify the test conditions
        expect(transcription.length).toEqual(50)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
    describe('and it does not end with a period', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription exactly fifty characters looong'

        // Verify the test conditions
        expect(transcription.length).toEqual(50)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
  })
  describe('Given a transcription equal to the max', () => {
    describe('and it ends with a period', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription that I believe should be exactly eighty characters in length.'

        // Verify the test conditions
        expect(transcription.length).toEqual(80)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
    describe('and it does not end with a period', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription that I believe should be exactly eighty characters in lengthh'

        // Verify the test conditions
        expect(transcription.length).toEqual(80)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
  })
  describe('Given a transcription greater than the min and less than the max', () => {
    describe('and there is no period', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription between min and max without a period'

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThanOrEqual(50)
        expect(transcription.length).toBeLessThanOrEqual(80)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
    describe('and there are two periods', () => {
      it('should return the transcription untruncated', () => {
        const transcription =
          'some transcription between min and max with a period.'

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThanOrEqual(50)
        expect(transcription.length).toBeLessThanOrEqual(80)

        expect(truncateTranscription(transcription)).toEqual(transcription)
      })
    })
  })
  describe('Given a transcription greater than the max', () => {
    describe('and there is no period', () => {
      it('should return the transcription truncated at the max', () => {
        const transcription =
          'some transcription greater than max without a period which means' +
          'we need a few more characters than the last few tests'

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThan(80)

        expect(truncateTranscription(transcription)).toEqual(
          transcription.substring(0, 80) + '…',
        )
      })
    })
    describe('and there is a period before the min', () => {
      describe('and no further periods', () => {
        it('should return the transcription truncated at the max', () => {
          const transcription =
            'some. transcription greater than max without a period which means' +
            'we need a few more characters than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(2)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(50)

          expect(truncateTranscription(transcription)).toEqual(
            transcription.substring(0, 80) + '…',
          )
        })
      })
      describe('and another period before the min', () => {
        it('should return the transcription truncated at the max', () => {
          const transcription =
            'some. transcription. greater than max without a period which means' +
            'we need a few more characters than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(50)
          expect(transcription.split('.')[1].length).toBeLessThanOrEqual(50)

          expect(truncateTranscription(transcription)).toEqual(
            transcription.substring(0, 80) + '…',
          )
        })
      })
      describe('and another period between the min and max', () => {
        it('should return the transcription truncated at the second period', () => {
          const transcription =
            'some. transcription greater than max without a period which means. ' +
            'we need a few more characters than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(50)
          expect(
            transcription.split('.')[0].length +
              transcription.split('.')[1].length,
          ).toBeGreaterThanOrEqual(50)
          expect(
            transcription.split('.')[0].length +
              transcription.split('.')[1].length,
          ).toBeLessThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            'some. transcription greater than max without a period which means.',
          )
        })
      })
      describe('and another period after the max', () => {
        it('should return the transcription truncated at the max', () => {
          const transcription =
            'some. transcription greater than max without a period which means ' +
            'we need a few more characters than the last. few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(50)
          expect(transcription.lastIndexOf('.')).toBeGreaterThan(80)

          expect(truncateTranscription(transcription)).toEqual(
            transcription.substring(0, 80) + '…',
          )
        })
      })
    })
    describe('and there is a period between the min and max', () => {
      describe('and no further periods', () => {
        it('should return the transcription truncated at the period', () => {
          const transcription =
            'some transcription greater than max without a period. which means ' +
            'we need a few more characters than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(2)
          expect(transcription.split('.')[0].length).toBeGreaterThanOrEqual(50)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            'some transcription greater than max without a period.',
          )
        })
      })
      describe('and another period between the min and max', () => {
        // TODO: The ideal behaviour here may be to truncate at the end of the
        // second period.
        it('should return the transcription truncated at the first period', () => {
          const transcription =
            'some transcription greater than max without a period. which. means ' +
            'we need a few more characters than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.split('.')[0].length).toBeGreaterThanOrEqual(50)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(80)
          expect(transcription.lastIndexOf('.')).toBeGreaterThanOrEqual(50)
          expect(transcription.lastIndexOf('.')).toBeLessThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            'some transcription greater than max without a period.',
          )
        })
      })
      describe('and another period after the max', () => {
        it('should return the transcription truncated at the first period', () => {
          const transcription =
            'some transcription greater than max without a period. which means ' +
            'we need a few more characters than the last few. tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.split('.')[0].length).toBeGreaterThanOrEqual(50)
          expect(transcription.split('.')[0].length).toBeLessThanOrEqual(80)
          expect(transcription.lastIndexOf('.')).toBeGreaterThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            'some transcription greater than max without a period.',
          )
        })
      })
    })
    describe('and there is a period after the max', () => {
      describe('and no further periods', () => {
        it('should return the transcription truncated at the max', () => {
          const transcription =
            'some transcription greater than max without a period which means ' +
            'we need a few more characters. than the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(2)
          expect(transcription.indexOf('.')).toBeGreaterThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            transcription.substring(0, 80) + '…',
          )
        })
      })
      describe('and another period after the max', () => {
        it('should return the transcription truncated at the max', () => {
          const transcription =
            'some transcription greater than max without a period which means ' +
            'we need a few more characters. than. the last few tests'

          // Verify the test conditions
          expect(transcription.length).toBeGreaterThan(80)
          expect(transcription.split('.').length).toEqual(3)
          expect(transcription.indexOf('.')).toBeGreaterThanOrEqual(80)
          expect(transcription.lastIndexOf('.')).toBeGreaterThanOrEqual(80)

          expect(truncateTranscription(transcription)).toEqual(
            transcription.substring(0, 80) + '…',
          )
        })
      })
    })
  })
})
describe('chunkTranscription', () => {
  // cases
  // - if transcription is less than min, return transcription
  describe('Given a transcription less than the min', () => {
    it('should return the transcription', () => {
      expect(
        chunkTranscription('some transcription', { min: 100, max: 200 }),
      ).toEqual(['some transcription'])
    })
  })
  describe('Given a transcription greater than the max', () => {
    describe('When theres a period after the min', () => {
      it('should chunk after the period', () => {
        const transcription =
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be. at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark.'

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThan(200)

        expect(
          chunkTranscription(transcription, {
            min: 100,
            max: 200,
          }),
        ).toEqual([
          // chunk 1
          'some transcription that is broken up into lines th' +
            'at are 50 characters long, so its easier to grok w' +
            'hat the expected behaviour will be.',
          // chunk 2
          ' at this point we only have a few more characters ' +
            'to go, before reaching the 200 total characters mar' +
            'k.',
        ])
      })
    })
    describe("When there's no period between min and max", () => {
      it('should chunk after the max', () => {
        const transcription =
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be, at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark.'

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThan(200)

        expect(
          chunkTranscription(transcription, {
            min: 100,
            max: 200,
          }),
        ).toEqual([
          // chunk 1
          'some transcription that is broken up into lines th' +
            'at are 50 characters long, so its easier to grok w' +
            'hat the expected behaviour will be, at this point ' +
            'we only have a few more characters to go, before r',
          // chunk 2
          'eaching the 200 total characters mark.',
        ])
      })
    })
  })
  describe('Given a transcription more than twice the size of the max', () => {
    describe('When there is always a period between the min and max', () => {
      it('should chunk after the periods', () => {
        const transcription =
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be. at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark. and again. ' +
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be. at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark. and again. '

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThan(400)

        expect(
          chunkTranscription(transcription, {
            min: 100,
            max: 200,
          }),
        ).toEqual([
          // chunk 1
          'some transcription that is broken up into lines th' +
            'at are 50 characters long, so its easier to grok w' +
            'hat the expected behaviour will be.',
          // chunk 2
          ' at this point we only have a few more characters ' +
            'to go, before reaching the 200 total characters ma' +
            'rk.',
          // chunk 3
          ' and again. some transcription that is broken up i' +
            'nto lines that are 50 characters long, so its easi' +
            'er to grok what the expected behaviour will be.',
          // chunk 4
          ' at this point we only have a few more characters ' +
            'to go, before reaching the 200 total characters ma' +
            'rk. and again. ',
        ])
      })
    })
    describe('When there are no periods between mins and maxes', () => {
      it('should chunk at the max each time', () => {
        const transcription =
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be, at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark, and again, ' +
          'some transcription that is broken up into lines th' +
          'at are 50 characters long, so its easier to grok w' +
          'hat the expected behaviour will be, at this point ' +
          'we only have a few more characters to go, before r' +
          'eaching the 200 total characters mark, and again, '

        // Verify the test conditions
        expect(transcription.length).toBeGreaterThan(400)

        expect(
          chunkTranscription(transcription, {
            min: 100,
            max: 200,
          }),
        ).toEqual([
          // chunk 1
          'some transcription that is broken up into lines th' +
            'at are 50 characters long, so its easier to grok w' +
            'hat the expected behaviour will be, at this point ' +
            'we only have a few more characters to go, before r',
          // chunk 2
          'eaching the 200 total characters mark, and again, ' +
            'some transcription that is broken up into lines th' +
            'at are 50 characters long, so its easier to grok w' +
            'hat the expected behaviour will be, at this point ',
          // chunk 3
          'we only have a few more characters to go, before r' +
            'eaching the 200 total characters mark, and again, ',
        ])
      })
    })
  })
  describe("Given a min that's 0 or less", () => {
    it('should throw ', () => {
      expect(() => {
        chunkTranscription('some transcription', { min: -1, max: 200 })
      }).toThrowError('min must be greater than 0')
    })
  })
  describe("Given a max that's less than the min", () => {
    it('should throw ', () => {
      expect(() => {
        chunkTranscription('some transcription', { min: 100, max: 99 })
      }).toThrowError('max must be greater than min')
    })
  })
})
