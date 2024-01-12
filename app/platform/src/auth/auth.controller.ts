import { AuthService } from '@exnota/auth/auth.service'
import { MagicAuthGuard } from '@exnota/auth/magic-auth.guard'
import { MagicStrategy } from '@exnota/auth/magic.strategy'
import { Public } from '@exnota/lib/public.annotation'
import {
  Controller,
  Request,
  Post,
  Get,
  UseGuards,
  Req,
  Res,
  Body,
} from '@nestjs/common'
import { IsEmail } from 'class-validator'

class MagicLoginBody {
  @IsEmail()
  destination: string
}

@Controller()
export class AuthController {
  constructor(
    private authService: AuthService,
    private strategy: MagicStrategy,
  ) {}

  @Post('auth/magic-login')
  @Public()
  async magicLogin(
    @Req() req: any,
    @Res() res: any,
    @Body() body: MagicLoginBody,
  ): Promise<void> {
    await this.authService.validateUserByEmail(body.destination)

    // This will add the following to the response object:
    // {
    //   "success": true,
    //   "code": "<code>"
    // }
    // The code can be displayed to the user to verify they are clicking the
    // link for the current login attempt.
    this.strategy.send(req, res)
  }

  // eslint-disable-next-line require-await
  @Get('auth/magic-success')
  @Public()
  @UseGuards(MagicAuthGuard)
  async magicSuccess(@Req() req: any, @Res() res: any): Promise<any> {
    const token = this.authService.getToken(req.user.userId)
    res.redirect(302, `exnota://auth/success?token=${token}`)
  }

  @Get('auth/profile')
  getProfile(@Request() req: any): Promise<any> {
    return req.user
  }
}
