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
import { diskStorage } from 'multer'

@Controller('notes')
export class NoteController {
  private readonly logger = new Logger(NoteController.name)

  constructor(private transcriptionService: TranscriptionService) {}

  @Get()
  getNote() {
    return 'audio memo'
  }

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: function (_req, _file, cb) {
          cb(null, '/tmp/upload/audio')
        },
        filename: function (_req, file, cb) {
          const uniqueSuffix =
            Date.now() + '-' + Math.round(Math.random() * 1e9)
          cb(null, file.fieldname + '-' + uniqueSuffix)
        },
      }),
    }),
  )
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
    this.logger.log(
      'Transcription:',
      this.transcriptionService.transcribe(file),
    )
  }
}
