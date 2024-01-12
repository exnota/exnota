import {
  NotionTokenServiceError,
  NotionTokenService,
} from '@exnota/integration/service/notion-token.service'
import { httpException } from '@exnota/lib/error'
import { Body, Controller, HttpStatus, Post } from '@nestjs/common'
import { IsNotEmpty, IsString } from 'class-validator'

class NotionTokenRequest {
  @IsNotEmpty()
  @IsString()
  code: string
}

@Controller('notion-token')
export class NotionTokenController {
  constructor(private notionTokenService: NotionTokenService) {}

  @Post()
  async notionToken(@Body() request: NotionTokenRequest): Promise<unknown> {
    const result = await this.notionTokenService.notionToken(request.code)
    if (!result.ok) {
      switch (result.type) {
        case NotionTokenServiceError.NOTION_AUTH_ERROR:
          throw httpException(HttpStatus.INTERNAL_SERVER_ERROR, result)
      }
    }
    return result.value
  }
}
