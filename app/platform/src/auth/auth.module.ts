import { Module } from '@nestjs/common'
import { AuthService } from './auth.service'
import { AccountModule } from '@exnota/account/account.module'
import { PassportModule } from '@nestjs/passport'
import { HttpBearerStrategy } from '@exnota/auth/http-bearer.strategy'
import { AuthController } from './auth.controller'
import { JwtModule } from '@nestjs/jwt'
import { DEPRECATED_jwtConstants } from './constants'
import { JwtStrategy } from '@exnota/auth/jwt.strategy'
import { APP_GUARD } from '@nestjs/core'
import { JwtAuthGuard } from '@exnota/auth/jwt-auth.guard'
import { MagicStrategy } from '@exnota/auth/magic.strategy'
import { ConfigModule } from '@nestjs/config'

@Module({
  imports: [
    AccountModule,
    PassportModule,
    ConfigModule,
    JwtModule.register({
      secret: DEPRECATED_jwtConstants.secret,
      // TODO: What is best practice?
      signOptions: { expiresIn: '365d' },
    }),
  ],
  providers: [
    AuthService,
    MagicStrategy,
    JwtStrategy,
    HttpBearerStrategy,
    // TODO: This should be updated to bearer
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
  controllers: [AuthController],
})
export class AuthModule {}
