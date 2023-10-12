import { Body, Controller, Post } from '@nestjs/common'
import { IsNotEmpty, IsString } from 'class-validator'

class NotionTokenRequest {
  @IsNotEmpty()
  @IsString()
  code: string
}

@Controller('notion-token')
export class NotionTokenController {
  @Post()
  notionToken(@Body() request: NotionTokenRequest) {
    return `You sent code: ${request.code}`
  }
}
