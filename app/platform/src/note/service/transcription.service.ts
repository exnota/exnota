import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'
import { readFileSync } from 'fs'
import { isTranscriptionOutput } from './transcription-output'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { parse as parsePath } from 'path'

export enum TranscribeError {
  NO_TRANSCRIPTION_GENERATED,
}

@Injectable()
export class TranscriptionService {
  async transcribe(path: string): Promise<Result<string, TranscribeError>> {
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
        return resultError(
          TranscribeError.NO_TRANSCRIPTION_GENERATED,
          'Could not read transcription result',
        )
      }
      if (json.transcription.length === 0) {
        return resultError(
          TranscribeError.NO_TRANSCRIPTION_GENERATED,
          'No transcription generated',
        )
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
      return resultError(
        TranscribeError.NO_TRANSCRIPTION_GENERATED,
        'Error generating transcription',
        e,
      )
    }
  }
}
