import { Module } from '@nestjs/common';
import { NoteController } from 'src/note/api/note.controller';

@Module({
  controllers: [NoteController],
})
export class NoteModule {}
