import { Module } from '@nestjs/common'
import { AuthService } from './auth.service'
import { AccountModule } from '@exnota/account/account.module'
import { PassportModule } from '@nestjs/passport'
import { LocalStrategy } from '@exnota/auth/local.strategy'
import { AuthController } from './auth.controller'
import { JwtModule } from '@nestjs/jwt'
import { DEPRECATED_jwtConstants } from './constants'
import { JwtStrategy } from '@exnota/auth/jwt.strategy'

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
  providers: [AuthService, LocalStrategy, JwtStrategy],
  controllers: [AuthController],
})
export class AuthModule {}
