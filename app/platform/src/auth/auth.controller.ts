import { AuthService } from '@exnota/auth/auth.service'
import { LocalAuthGuard } from '@exnota/auth/local-auth.guard'
import { Public } from '@exnota/lib/public.annotation'
import { Controller, Request, Post, Get, UseGuards } from '@nestjs/common'

@Controller()
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('auth/login')
  @Public()
  @UseGuards(LocalAuthGuard)
  async login(@Request() req: any) {
    return this.authService.login(req.user)
  }

  @Get('auth/profile')
  getProfile(@Request() req: any) {
    return req.user
  }
}
