import { Module } from '@nestjs/common'
import { ExportService } from './service/export.service'
import { ConfigModule } from '@nestjs/config'

@Module({
  providers: [ExportService],
  exports: [ExportService],
  imports: [ConfigModule.forRoot()],
})
export class IntegrationModule {}
