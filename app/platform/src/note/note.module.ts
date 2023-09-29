import { Module } from '@nestjs/common';
import { NoteController } from '@exnota/note/api/note.controller';
import { TranscriptionService } from '@exnota/note/service/transcription.service';

@Module({
  controllers: [NoteController],
  providers: [TranscriptionService],
})
export class NoteModule {}
