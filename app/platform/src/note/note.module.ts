import { Module } from '@nestjs/common';
import { NoteController } from 'src/note/api/note.controller';
import { TranscriptionService } from './service/transcription.service';

@Module({
  controllers: [NoteController],
  providers: [TranscriptionService],
})
export class NoteModule {}
