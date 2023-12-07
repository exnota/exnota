const TITLE_MIN = 50
const TITLE_MAX = 80

// Notion has a 2000 char limit for titles and block content.
const CONTENT_MIN = 1600
const CONTENT_MAX = 1950

function truncateTranscription(transcription: string): string {
  return getByPeriod({
    transcription,
    min: TITLE_MIN,
    max: TITLE_MAX,
  })
}

function getByPeriod(options: {
  transcription: string
  startingAt?: number
  min: number
  max: number
  clipChar?: string
}): string {
  const startingAt = options.startingAt ?? 0
  const clipChar = options.clipChar ?? '…'
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
    return transcription.substring(0, max) + clipChar
  }

  if (periodIndex < min) {
    return getByPeriod({
      transcription,
      startingAt: periodIndex + 1,
      min,
      max,
      clipChar,
    })
  }

  if (periodIndex < max) {
    return transcription.substring(0, periodIndex + 1)
  }

  return transcription.substring(0, max) + clipChar
}

// This is a simple implementation, with the expectation that the transcription
// will usually be broken into paragraphs.
function chunkTranscription(
  transcription: string,
  options: { min?: number; max?: number },
): string[] {
  const chunks = []
  let remaining = transcription
  while (remaining.length > 0) {
    const chunk = getByPeriod({
      transcription: remaining,
      min: options.min ?? CONTENT_MIN,
      max: options.max ?? CONTENT_MAX,
      clipChar: '',
    })
    chunks.push(chunk)
    remaining = remaining.substring(chunk.length)
  }
  return chunks
}

export { chunkTranscription, truncateTranscription }
