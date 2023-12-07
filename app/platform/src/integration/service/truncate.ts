const MIN = 50
const MAX = 80

function truncateTranscription(transcription: string): string {
  return getByPeriod({
    transcription,
    min: MIN,
    max: MAX,
  })
}

function getByPeriod(options: {
  transcription: string
  startingAt?: number
  min: number
  max: number
}): string {
  const startingAt = options.startingAt ?? 0
  const { transcription, min, max } = options
  if (min <= 0) {
    throw new Error('min must be greater than 0')
  }
  if (max < min) {
    throw new Error('max must be greater than min')
  }
  if (startingAt < 0) {
    throw new Error('startingAt must be greater than or equal to 0')
  }

  if (transcription.length <= max) {
    return transcription
  }
  const periodIndex = transcription.indexOf('.', startingAt)
  if (periodIndex === -1) {
    return transcription.substring(0, max) + '…'
  }

  if (periodIndex < min) {
    return getByPeriod({
      transcription,
      startingAt: periodIndex + 1,
      min,
      max,
    })
  }

  if (periodIndex < max) {
    return transcription.substring(0, periodIndex + 1)
  }

  return transcription.substring(0, max) + '…'
}

export { truncateTranscription }
