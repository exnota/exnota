import { Test, TestingModule } from '@nestjs/testing'
import { NotionTokenService } from './notion-token.service'

describe('NotionTokenService', () => {
  let service: NotionTokenService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [NotionTokenService],
    }).compile()

    service = module.get<NotionTokenService>(NotionTokenService)
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
