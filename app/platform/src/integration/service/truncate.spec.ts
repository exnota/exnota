import { truncateTranscription } from '@exnota/integration/service/truncate'

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
