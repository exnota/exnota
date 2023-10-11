import { Module } from '@nestjs/common'
import { ExportService } from './service/export.service'

@Module({
  providers: [ExportService],
  exports: [ExportService],
})
export class IntegrationModule {}
