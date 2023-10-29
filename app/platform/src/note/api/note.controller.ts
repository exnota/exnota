import {
  Controller,
  Body,
  FileTypeValidator,
  Get,
  HttpStatus,
  Logger,
  ParseFilePipe,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import {
  TranscribeError,
  TranscriptionService,
} from '@exnota/note/service/transcription.service'
import { diskStorage } from 'multer'
import { PATH_UPLOAD_AUDIO } from '@exnota/settings'
import { format as dateFormat } from 'date-fns'
import { extname } from 'path'
import { Equals, IsIn, IsNotEmpty, IsString, validate } from 'class-validator'
import {
  ExportError,
  ExportService,
} from '@exnota/integration/service/export.service'
import { httpException } from '@exnota/lib/error'
import {
  FileStorageService,
  FileStorageServiceError,
} from '@exnota/note/service/file-storage.service'

enum NoteError {
  AUTH_ERROR = 'AUTH_ERROR',
  NO_PAGE_ERROR = 'NO_PAGE_ERROR',
  UNEXPECTED = 'UNEXPECTED',
  UPLOAD_ERROR = 'UPLOAD_ERROR',
  CREDENTIALS_MISSING = 'CREDENTIALS_MISSING',
}

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
    private fileStorageService: FileStorageService,
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
  ) {
    // Audio file
    const { buffer: _, stream: __, ...logData } = file
    this.logger.log('File uploaded:', logData)

    // Check type
    if (note.type !== 'audio') {
      throw httpException(HttpStatus.NOT_IMPLEMENTED, {
        message: 'Only audio notes supported',
      })
    }
    const audioNote = new AudioNote()
    audioNote.accessToken = note.accessToken
    audioNote.type = note.type

    const errors = await validate(audioNote)
    if (errors.length) {
      throw httpException(HttpStatus.BAD_REQUEST, {
        message: errors.map((e) => e.toString()).join('; '),
      })
    }

    const transcriptionResult = await this.transcriptionService.transcribe(
      file.path,
    )
    if (!transcriptionResult.ok) {
      switch (transcriptionResult.type) {
        case TranscribeError.NO_TRANSCRIPTION_GENERATED:
          throw httpException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            transcriptionResult,
            NoteError.UNEXPECTED,
          )
      }
    }

    const exportResult = await this.exportService.export(
      {
        title: transcriptionResult.value,
      },
      {
        token: audioNote.accessToken,
      },
    )

    if (!exportResult.ok) {
      switch (exportResult.type) {
        case ExportError.AUTH_ERROR:
          throw httpException(
            HttpStatus.UNAUTHORIZED,
            exportResult,
            NoteError.AUTH_ERROR,
          )
        case ExportError.NO_PAGES_SHARED:
        case ExportError.NO_VALID_PAGE:
          throw httpException(
            HttpStatus.UNAUTHORIZED,
            exportResult,
            NoteError.NO_PAGE_ERROR,
          )
        case ExportError.UNKNOWN_NOTION_ERROR:
        case ExportError.UNKNOWN_ERROR:
        case ExportError.INTERNAL_ERROR:
          throw httpException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            exportResult,
            NoteError.UNEXPECTED,
          )
      }
    }

    const uploadResult = await this.fileStorageService.upload(file.path)
    if (!uploadResult.ok) {
      switch (uploadResult.type) {
        case FileStorageServiceError.CREDENTIALS_MISSING:
          throw httpException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            uploadResult,
            NoteError.CREDENTIALS_MISSING,
          )
        case FileStorageServiceError.UPLOAD_ERROR:
          throw httpException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            uploadResult,
            NoteError.UPLOAD_ERROR,
          )
      }
    }
    this.logger.log('Upload result:', uploadResult.value.url)

    // Ignore result, because there's no action to take if the audio wasn't
    // added to the Notion page.
    await this.exportService.addAudio(
      exportResult.value.id,
      uploadResult.value.url,
      {
        token: audioNote.accessToken,
      },
    )

    return {
      transcription: transcriptionResult.value,
      url: exportResult.value.url,
    }
  }
}
