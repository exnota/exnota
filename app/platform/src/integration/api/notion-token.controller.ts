import { NotionTokenService } from '@exnota/integration/service/notion-token.service'
import {
  Body,
  Controller,
  HttpException,
  HttpStatus,
  Post,
} from '@nestjs/common'
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
  async notionToken(@Body() request: NotionTokenRequest) {
    const result = await this.notionTokenService.notionToken(request.code)
    if (!result.ok) {
      throw new HttpException(
        result.message,
        HttpStatus.INTERNAL_SERVER_ERROR,
        {
          cause: result.error,
        },
      )
    }
    return result.value
  }
}
