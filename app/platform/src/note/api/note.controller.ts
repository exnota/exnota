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
import { PATH_UPLOAD_AUDIO } from '@exnota/settings'
import { format as dateFormat } from 'date-fns'
import { extname } from 'path'

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
          cb(null, PATH_UPLOAD_AUDIO)
        },
        filename: function (_req, file, cb) {
          const ext = extname(file.originalname).replace(/\./, '')
          const uniqueSuffix =
            dateFormat(Date.now(), 'yyyyMMdd-HHmmss') +
            '-' +
            Math.round(Math.random() * 1e9) +
            (!!ext ? `.${ext}` : '')
          cb(null, uniqueSuffix)
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
    const transcription = this.transcriptionService.transcribe(file.path)
    this.logger.log('Transcription:', transcription)
    return transcription
  }
}
