import { Result, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'

type NoteExport = {
  title: string
}

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name)

  constructor(private configService: ConfigService) {}

  async export(note: NoteExport): Promise<Result<null>> {
    const oneExpected =
      this.configService.get('NOTION_OAUTH_CLIENT_ID') ===
      'DUMMY_NOTION_OAUTH_CLIENT_ID'
    const twoExpected =
      this.configService.get('NOTION_OAUTH_CLIENT_SECRET') ===
      'DUMMY_NOTION_OAUTH_CLIENT_SECRET'
    const threeExpected =
      this.configService.get('NOTION_AUTH_URL') === 'DUMMY_NOTION_AUTH_URL'

    this.logger.log(oneExpected)
    this.logger.log(twoExpected)
    this.logger.log(threeExpected)

    this.logger.log(`Received note to export:`, note)
    return resultOk(null)
  }
}
