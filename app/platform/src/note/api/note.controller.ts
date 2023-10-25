import {
  Controller,
  Body,
  FileTypeValidator,
  Get,
  HttpException,
  HttpStatus,
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
import { Equals, IsIn, IsNotEmpty, IsString, validate } from 'class-validator'
import { ExportService } from '@exnota/integration/service/export.service'

class Note {
  @IsIn(['audio', 'text'])
  type: 'audio' | 'text'

  @IsString()
  @IsNotEmpty()
  accessToken: string
}

class AudioNote implements Note {
  @Equals('audio')
  type: 'audio'

  @IsString()
  @IsNotEmpty()
  accessToken: string
}

// Using a polymorphic API approach for notes - i.e. not having /note-audio,
// /note-text, etc -- because most consumption will be polymorphic. E.g. the app
// will display a list of notes and its queue for offline processing will not
// care about the type (mostly).
@Controller('note/notes')
export class NoteController {
  private readonly logger = new Logger(NoteController.name)

  constructor(
    private transcriptionService: TranscriptionService,
    private exportService: ExportService,
  ) {}

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
          const uniqueFilename =
            dateFormat(Date.now(), 'yyyyMMdd-HHmmss') +
            '-' +
            Math.round(Math.random() * 1e9) +
            (!!ext ? `.${ext}` : '')
          cb(null, uniqueFilename)
        },
      }),
    }),
  )
  async postNote(
    @UploadedFile(
      new ParseFilePipe({
        validators: [new FileTypeValidator({ fileType: /audio\/(x-m4a|wav)/ })],
      }),
    )
    file: Express.Multer.File,
    @Body() note: Note,
    // @Req() req: Request,
  ) {
    this.logger.log('hi')
    // Audio file
    const { buffer: _, stream: __, ...logData } = file
    this.logger.log('File uploaded:', logData)

    // Check type
    if (note.type !== 'audio') {
      throw new HttpException(
        'Only audio notes supported',
        HttpStatus.NOT_IMPLEMENTED,
      )
    }
    const audioNote = new AudioNote()
    audioNote.accessToken = note.accessToken
    audioNote.type = note.type

    const errors = await validate(audioNote)
    if (errors.length) {
      throw new HttpException(
        errors.map((e) => e.toString()).join('; '),
        HttpStatus.BAD_REQUEST,
      )
    }

    const transcriptionResult = await this.transcriptionService.transcribe(
      file.path,
    )
    if (!transcriptionResult.ok) {
      throw new HttpException(
        transcriptionResult.message,
        HttpStatus.INTERNAL_SERVER_ERROR,
        {
          cause: transcriptionResult.error,
        },
      )
    }

    const exportResult = await this.exportService.export({
      title: transcriptionResult.value,
      accessToken: audioNote.accessToken,
    })

    if (!exportResult.ok) {
      throw new HttpException(
        exportResult.message,
        HttpStatus.INTERNAL_SERVER_ERROR,
        {
          cause: exportResult.error,
        },
      )
    }
    return transcriptionResult.value
  }
}
