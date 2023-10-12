import { Test, TestingModule } from '@nestjs/testing'
import { NotionTokenController } from './notion-token.controller'

describe('NotionTokenController', () => {
  let controller: NotionTokenController

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NotionTokenController],
    }).compile()

    controller = module.get<NotionTokenController>(NotionTokenController)
  })

  it('should be defined', () => {
    expect(controller).toBeDefined()
  })
})
