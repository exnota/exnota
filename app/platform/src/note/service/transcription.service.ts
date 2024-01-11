import { Injectable, Logger } from '@nestjs/common'
import { exec as execShell } from 'shelljs'
import { readFile } from 'fs/promises'
import { isTranscriptionOutput } from './transcription-output'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { parse as parsePath } from 'path'
import { ConfigService } from '@nestjs/config'
import OpenAI from 'openai'
import * as fs from 'fs'
import { Config, ConfigKey } from '@exnota/config'

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const PROMPT = 'Hello, welcome to my lecture.'

export enum TranscribeError {
  NO_TRANSCRIPTION_GENERATED = 'NO_TRANSCRIPTION_GENERATED',
  OPENAI_REQUEST_ERROR = 'OPENAI_REQUEST_ERROR',
}

type TranscribeResult = {
  local: string
  openAi?: string
}

@Injectable()
export class TranscriptionService {
  private readonly logger = new Logger(TranscriptionService.name)

  constructor(private configService: ConfigService<Config>) {}

  async transcribe(
    path: string,
    enableTestData: boolean,
  ): Promise<Result<TranscribeResult, TranscribeError>> {
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
      const local = json.transcription.reduce((prev, cur) => {
        if (prev === '') {
          return cur.text
        } else {
          return `${prev} ${cur.text}`
        }
      }, '')

      let openAi: string | undefined
      if (enableTestData) {
        const openAiResult = await this.getOpenAiTranscription({
          path: convertedPath,
        })
        if (!openAiResult.ok) {
          return openAiResult
        }
        openAi = openAiResult.value
        // TODO: Remove log
        this.logger.log(`OpenAI transcription: ${openAi}`)
      }

      return resultOk({
        local,
        openAi,
      })
    } catch (e) {
      return resultError(
        TranscribeError.NO_TRANSCRIPTION_GENERATED,
        'Error generating transcription',
        e,
      )
    }
  }

  private async getOpenAiTranscription({
    path,
  }: {
    path: string
  }): Promise<Result<string, TranscribeError>> {
    // Get OPENAI_KEY from configService
    const apiKey = this.configService.get(ConfigKey.OPENAI_KEY, {
      infer: true,
    })

    const openai = new OpenAI({
      apiKey: apiKey, // This is the default and can be omitted
    })

    let transcription: string
    try {
      const result = await openai.audio.transcriptions.create({
        file: fs.createReadStream(path),
        model: 'whisper-1',
      })
      transcription = result.text
    } catch (error) {
      return resultError(
        TranscribeError.OPENAI_REQUEST_ERROR,
        'Error transcribing audio',
        error,
      )
    }

    return resultOk(transcription)
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
