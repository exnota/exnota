import { Controller, Get, Req, Res } from '@nestjs/common'
import type { Response, Request } from 'express'

@Controller('integration/notion/mobile-code-redirect')
export class NotionMobileCodeRedirectController {
  @Get()
  async notionMobileCodeRedirect(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const code = req.query.code
    if (code) {
      res.redirect(
        302,
        `exnota://integration/notion/mobile-code-redirect?code=${code}`,
      )
    }
  }
}
