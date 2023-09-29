import { Test, TestingModule } from '@nestjs/testing';
import { NewAudioMemoController } from './new-audio-memo.controller';

describe('NewAudioMemoController', () => {
  let controller: NewAudioMemoController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NewAudioMemoController],
    }).compile();

    controller = module.get<NewAudioMemoController>(NewAudioMemoController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
