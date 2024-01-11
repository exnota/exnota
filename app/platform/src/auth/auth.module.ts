import { Module } from '@nestjs/common'
import { AuthService } from './auth.service'
import { AccountModule } from '@exnota/account/account.module'
import { PassportModule } from '@nestjs/passport'
import { LocalStrategy } from '@exnota/auth/local.strategy'
import { AuthController } from './auth.controller'
import { JwtModule } from '@nestjs/jwt'
import { DEPRECATED_jwtConstants } from './constants'
import { JwtStrategy } from '@exnota/auth/jwt.strategy'
import { APP_GUARD } from '@nestjs/core'
import { JwtAuthGuard } from '@exnota/auth/jwt-auth.guard'

@Module({
  imports: [
    AccountModule,
    PassportModule,
    JwtModule.register({
      secret: DEPRECATED_jwtConstants.secret,
      // TODO: What is best practice?
      signOptions: { expiresIn: '365d' },
    }),
  ],
  providers: [
    AuthService,
    LocalStrategy,
    JwtStrategy,
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
  controllers: [AuthController],
})
export class AuthModule {}
