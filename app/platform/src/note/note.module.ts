import { Module } from '@nestjs/common'
import { NoteController } from '@exnota/note/api/note.controller'
import { TranscriptionService } from '@exnota/note/service/transcription.service'
import { IntegrationModule } from '@exnota/integration/integration.module'
import { FileStorageService } from './file-storage/file-storage.service'
import { ConfigModule } from '@nestjs/config'

@Module({
  controllers: [NoteController],
  providers: [TranscriptionService, FileStorageService],
  imports: [IntegrationModule, ConfigModule.forRoot()],
})
export class NoteModule {}
