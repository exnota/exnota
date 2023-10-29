import { Test, TestingModule } from '@nestjs/testing'
import { NotionAuthService } from './notion-auth.service'

describe('NotionAuthService', () => {
  let service: NotionAuthService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [NotionAuthService],
    }).compile()

    service = module.get<NotionAuthService>(NotionAuthService)
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
