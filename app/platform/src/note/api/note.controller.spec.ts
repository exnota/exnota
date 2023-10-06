import { Test, TestingModule } from '@nestjs/testing'
import { NoteController } from '@exnota/note/api/note.controller'
import { TranscriptionService } from '@exnota/note/service/transcription.service'

describe('NoteController', () => {
  let controller: NoteController

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NoteController],
      providers: [TranscriptionService],
    }).compile()

    controller = module.get<NoteController>(NoteController)
  })

  it('should be defined', () => {
    expect(controller).toBeDefined()
  })
})
