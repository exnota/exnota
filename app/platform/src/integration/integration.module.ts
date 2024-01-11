import { Module } from '@nestjs/common'
import { ExportService } from './service/export.service'
import { NotionTokenController } from './api/notion-token.controller'
import { NotionTokenService } from './service/notion-token.service'
import { NotionMobileCodeRedirectController } from '@exnota/integration/api/notion-mobile-code-redirect.controller'
import { NotionAuthService } from './service/notion-auth.service'

@Module({
  providers: [ExportService, NotionTokenService, NotionAuthService],
  exports: [ExportService],
  controllers: [NotionMobileCodeRedirectController, NotionTokenController],
})
export class IntegrationModule {}
