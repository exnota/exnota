import { Injectable } from '@nestjs/common'
import { exec, tempdir } from 'shelljs'

@Injectable()
export class TranscriptionService {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  transcribe(file: Express.Multer.File): string {
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f /home/node/whisper/audio/jfk.wav --output-json --output-file ${tempdir()}/jfk`,
    )
    return 'transcription9'
  }
}
