import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'
import { readFileSync } from 'fs'
import { isTranscriptionOutput } from './transcription-output'

@Injectable()
export class TranscriptionService {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  transcribe(path: string): string | null {
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f ${path} --output-json`,
    )
    try {
      const contents = readFileSync(`${path}.json`, 'utf8')
      const json = JSON.parse(contents)
      if (!isTranscriptionOutput(json)) {
        // TODO: Error instead?
        return null
      }
      if (json.transcription.length === 0) {
        // TODO: Error instead?
        return null
      }
      return json.transcription.reduce((prev, cur) => {
        if (prev === '') {
          return cur.text
        } else {
          return `${prev} ${cur.text}`
        }
      }, '')
    } catch (e) {
      // TODO: Error instead?
      return null
    }
  }
}
