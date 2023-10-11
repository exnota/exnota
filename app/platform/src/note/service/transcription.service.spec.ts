import { Test, TestingModule } from '@nestjs/testing'
import { TranscriptionService } from '@exnota/note/service/transcription.service'
import { IntegrationModule } from '@exnota/integration/integration.module'

describe('TranscriptionService', () => {
  let service: TranscriptionService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [TranscriptionService],
      imports: [IntegrationModule],
    }).compile()

    service = module.get<TranscriptionService>(TranscriptionService)
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
