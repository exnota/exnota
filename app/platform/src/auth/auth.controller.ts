import { AuthService } from '@exnota/auth/auth.service'
import { HttpBearerGuard } from '@exnota/auth/http-bearer.guard'
import { LocalAuthGuard } from '@exnota/auth/local-auth.guard'
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

  @Post('auth/login')
  @Public()
  @UseGuards(LocalAuthGuard)
  async login(@Request() req: any): Promise<{ access_token: string }> {
    return await this.authService.login(req.user)
  }

  @Post('auth/magic-login')
  @Public()
  async magicLogin(
    @Req() req: any,
    @Res() res: any,
    @Body() body: MagicLoginBody,
  ): Promise<void> {
    await this.authService.validateUserByEmail(body.destination)
    return this.strategy.send(req, res)
  }

  // eslint-disable-next-line require-await
  @Get('auth/magic-success')
  @Public()
  @UseGuards(MagicAuthGuard)
  async magicSuccess(@Req() req: any, @Res() res: any): Promise<any> {
    const token = this.authService.getToken(req.user.userId)
    res.redirect(302, `exnota://auth/success?token=${token}`)
  }

  @Public()
  @UseGuards(HttpBearerGuard)
  @Get('auth/profile')
  getProfile(@Request() req: any): Promise<any> {
    return req.user
  }
}
