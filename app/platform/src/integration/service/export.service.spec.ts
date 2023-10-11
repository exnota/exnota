import { Test, TestingModule } from '@nestjs/testing'
import { ExportService } from './export.service'
import { ConfigModule } from '@nestjs/config'

describe('ExportService', () => {
  let service: ExportService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [ExportService],
      imports: [ConfigModule.forRoot()],
    }).compile()

    service = module.get<ExportService>(ExportService)
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
