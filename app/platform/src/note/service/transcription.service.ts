import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class TranscriptionService {
  private readonly logger = new Logger(TranscriptionService.name);

  async transcribe(): Promise<string> {
    return Promise.resolve('transcription4');
  }
}
