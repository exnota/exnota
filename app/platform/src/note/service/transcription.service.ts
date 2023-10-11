import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'
import { readFileSync } from 'fs'
import { isTranscriptionOutput } from './transcription-output'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { ExportService } from '@exnota/integration/service/export.service'

@Injectable()
export class TranscriptionService {
  constructor(private exportService: ExportService) {}

  async transcribe(path: string): Promise<Result<string>> {
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f ${path} --output-json`,
    )
    try {
      const contents = readFileSync(`${path}.json`, 'utf8')
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
      await this.exportService.export({
        title: transcription,
      })
      return resultOk(transcription)
    } catch (e) {
      return resultError('Error generating transcription', e)
    }
  }
}
