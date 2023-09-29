import {
  Controller,
  Get,
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
  postNote(@UploadedFile() file: Express.Multer.File) {
    console.log(file);
  }
}
