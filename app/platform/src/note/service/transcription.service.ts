import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'
import { readFileSync } from 'fs'
import { isTranscriptionOutput } from './transcription-output'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { parse as parsePath } from 'path'

@Injectable()
export class TranscriptionService {
  async transcribe(path: string): Promise<Result<string>> {
    const parsedPath = parsePath(path)
    const convertedPath =
      parsedPath.dir + '/' + parsedPath.name + '-converted.wav'

    exec(`ffmpeg -i ${path} -ar 16000 -ac 1 -c:a pcm_s16le ${convertedPath}`)
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f ${convertedPath} --output-json`,
    )
    try {
      const contents = readFileSync(`${convertedPath}.json`, 'utf8')
      const json = JSON.parse(contents)
      if (!isTranscriptionOutput(json)) {
        return resultError('Could not read transcription result')
      }
      if (json.transcription.length === 0) {
        return resultError('No transcription generated')
      }
      const transcription = json.transcription.reduce((prev, cur) => {
        if (prev === '') {
          return cur.text
        } else {
          return `${prev} ${cur.text}`
        }
      }, '')
      return resultOk(transcription.trim())
    } catch (e) {
      return resultError('Error generating transcription', e)
    }
  }
}
