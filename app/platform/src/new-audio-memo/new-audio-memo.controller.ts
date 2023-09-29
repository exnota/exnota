import { Controller, Get } from '@nestjs/common';

@Controller('new-audio-memo')
export class NewAudioMemoController {
  @Get()
  newAudioMemo() {
    return 'audio memo';
  }
}
