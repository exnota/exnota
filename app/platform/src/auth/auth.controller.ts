import { AuthService } from '@exnota/auth/auth.service'
import { JwtAuthGuard } from '@exnota/auth/jwt-auth.guard'
import { LocalAuthGuard } from '@exnota/auth/local-auth.guard'
import { Controller, Request, Post, UseGuards, Get } from '@nestjs/common'

@Controller()
export class AuthController {
  constructor(private authService: AuthService) {}

  @UseGuards(LocalAuthGuard)
  @Post('auth/login')
  async login(@Request() req: any) {
    return this.authService.login(req.user)
  }

  @UseGuards(JwtAuthGuard)
  @Get('auth/profile')
  getProfile(@Request() req: any) {
    return req.user
  }
}
