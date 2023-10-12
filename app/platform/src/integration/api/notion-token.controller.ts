import { Body, Controller, Post } from '@nestjs/common'

class NotionTokenRequest {
  code: string
}

@Controller('notion-token')
export class NotionTokenController {
  @Post()
  notionToken(@Body() request: NotionTokenRequest) {
    return `You sent code: ${request.code}`
  }
}
