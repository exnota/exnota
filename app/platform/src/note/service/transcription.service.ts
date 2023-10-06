import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'

@Injectable()
export class TranscriptionService {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  transcribe(path: string): string {
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f ${path} --output-json`,
    )
    return 'transcription10'
  }
}
