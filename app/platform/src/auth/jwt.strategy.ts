import { ExtractJwt, Strategy } from 'passport-jwt'
import { PassportStrategy } from '@nestjs/passport'
import { Injectable } from '@nestjs/common'
import { DEPRECATED_jwtConstants } from './constants'

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: DEPRECATED_jwtConstants.secret,
    })
  }

  // Note: This is executed *after* auth is successful. If auth fails, it won't
  // run.
  async validate(payload: any) {
    return { userId: payload.sub, username: payload.username }
  }
}
