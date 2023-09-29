import { Module } from '@nestjs/common';
import { NewAudioMemoController } from 'src/new-audio-memo/new-audio-memo.controller';

@Module({
  controllers: [NewAudioMemoController],
})
export class NoteModule {}
