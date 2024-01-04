import { Injectable } from '@nestjs/common'
import { exec as execShell } from 'shelljs'
import { readFile } from 'fs/promises'
import { isTranscriptionOutput } from './transcription-output'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { parse as parsePath } from 'path'

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const PROMPT = 'Hello, welcome to my lecture.'

export enum TranscribeError {
  NO_TRANSCRIPTION_GENERATED = 'NO_TRANSCRIPTION_GENERATED',
}

@Injectable()
export class TranscriptionService {
  async transcribe(path: string): Promise<Result<string, TranscribeError>> {
    const parsedPath = parsePath(path)
    const convertedPath =
      parsedPath.dir + '/' + parsedPath.name + '-converted.wav'

    await exec(
      `ffmpeg -i ${path} -ar 16000 -ac 1 -c:a pcm_s16le ${convertedPath}`,
    )
    await exec(
      `whisper --prompt "${PROMPT}" --model /home/node/whisper/models/ggml-base.bin -f ${convertedPath} --output-json`,
    )
    try {
      const contents = await readFile(`${convertedPath}.json`, 'utf8')
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

// Wrap shelljs.exec in a promise to not block the event loop.
function exec(command: any): Promise<string> {
  return new Promise((resolve, reject) =>
    execShell(command, {}, (code, value, error) => {
      if (code) {
        return reject({ error, code })
      }
      resolve(value)
    }),
  )
}
