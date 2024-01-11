import { AuthService } from '@exnota/auth/auth.service'
import { LocalAuthGuard } from '@exnota/auth/local-auth.guard'
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
  async login(@Request() req: any) {
    return await this.authService.login(req.user)
  }

  @Post('auth/magic-login')
  @Public()
  async magicLogin(
    @Req() req: any,
    @Res() res: any,
    @Body() body: MagicLoginBody,
  ) {
    await this.authService.validateUserByEmail(body.destination)
    return this.strategy.send(req, res)
  }

  @Get('auth/profile')
  getProfile(@Request() req: any) {
    return req.user
  }
}
