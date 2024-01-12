import { Module } from '@nestjs/common'
import { AuthService } from './auth.service'
import { AccountModule } from '@exnota/account/account.module'
import { PassportModule } from '@nestjs/passport'
import { HttpBearerStrategy } from '@exnota/auth/http-bearer.strategy'
import { AuthController } from './auth.controller'
import { APP_GUARD } from '@nestjs/core'
import { MagicStrategy } from '@exnota/auth/magic.strategy'
import { ConfigModule } from '@nestjs/config'
import { HttpBearerGuard } from '@exnota/auth/http-bearer.guard'

@Module({
  imports: [AccountModule, PassportModule, ConfigModule],
  providers: [
    AuthService,
    MagicStrategy,
    HttpBearerStrategy,
    {
      provide: APP_GUARD,
      useClass: HttpBearerGuard,
    },
  ],
  controllers: [AuthController],
})
export class AuthModule {}
