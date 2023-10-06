type TranscriptionOutput = {
  transcription: Array<{
    text: string
  }>
}

export const isTranscriptionOutput = (
  json: unknown,
): json is TranscriptionOutput => {
  if (typeof json !== 'object' || json === null) {
    return false
  }
  if (!('transcription' in json) || !(json.transcription instanceof Array)) {
    return false
  }

  for (const t of json.transcription) {
    if (typeof t !== 'object' || t === null) {
      return false
    }
    if (!('text' in t)) {
      return false
    }
  }

  return true
}
