import { Controller, Get } from '@nestjs/common';

@Controller('notes')
export class NoteController {
  @Get('')
  getNote() {
    return 'audio memo';
  }
}
