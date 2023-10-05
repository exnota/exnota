import { PATH_UPLOAD_AUDIO } from '@exnota/settings'
import { Injectable } from '@nestjs/common'
import { exec } from 'shelljs'

@Injectable()
export class TranscriptionService {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  transcribe(file: Express.Multer.File): string {
    exec(
      `whisper --model /home/node/whisper/models/ggml-base.bin -f /home/node/whisper/audio/jfk.wav --output-json --output-file ${PATH_UPLOAD_AUDIO}/jfk`,
    )
    return 'transcription10'
  }
}
