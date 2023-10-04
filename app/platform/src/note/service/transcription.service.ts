import { Injectable } from '@nestjs/common'

@Injectable()
export class TranscriptionService {
  transcribe(): string {
    return 'transcription4'
  }
}
