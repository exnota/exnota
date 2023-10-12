import { Module } from '@nestjs/common'
import { ExportService } from './service/export.service'
import { ConfigModule } from '@nestjs/config'
import { NotionTokenController } from './api/notion-token.controller'
import { NotionTokenService } from './service/notion-token.service'

@Module({
  providers: [ExportService, NotionTokenService],
  exports: [ExportService],
  imports: [ConfigModule.forRoot()],
  controllers: [NotionTokenController],
})
export class IntegrationModule {}
