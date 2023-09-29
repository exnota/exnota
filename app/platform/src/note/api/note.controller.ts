import {
  Controller,
  FileTypeValidator,
  Get,
  ParseFilePipe,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

@Controller('notes')
export class NoteController {
  @Get()
  getNote() {
    return 'audio memo';
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
    console.log(file);
  }
}
