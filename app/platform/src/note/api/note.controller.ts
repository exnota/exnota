import {
  Controller,
  FileTypeValidator,
  Get,
  Logger,
  ParseFilePipe,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import { TranscriptionService } from '@exnota/note/service/transcription.service'

@Controller('notes')
export class NoteController {
  private readonly logger = new Logger(NoteController.name)

  constructor(private transcriptionService: TranscriptionService) {}

  @Get()
  getNote() {
    return 'audio memo'
  }

  @Post()
  @UseInterceptors(FileInterceptor('file'))
  postNote(
    @UploadedFile(
      new ParseFilePipe({
        validators: [new FileTypeValidator({ fileType: 'audio/wav' })],
      }),
    )
    file: Express.Multer.File,
  ) {
    const { buffer: _, stream: __, ...logData } = file
    this.logger.log('File:', logData)
    this.logger.log('Transcription:', this.transcriptionService.transcribe())
  }
}
