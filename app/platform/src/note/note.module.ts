import { Module } from '@nestjs/common'
import { NoteController } from '@exnota/note/api/note.controller'
import { TranscriptionService } from '@exnota/note/service/transcription.service'
import { IntegrationModule } from '@exnota/integration/integration.module'

@Module({
  controllers: [NoteController],
  providers: [TranscriptionService],
  imports: [IntegrationModule],
})
export class NoteModule {}
