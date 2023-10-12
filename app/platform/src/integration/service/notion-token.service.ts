import { Result, resultError } from '@exnota/lib/result'
import { Injectable } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'

@Injectable()
export class NotionTokenService {
  constructor(private configService: ConfigService) {}

  async notionToken(): Promise<Result<unknown>> {
    return resultError('not implemented')
  }
}
