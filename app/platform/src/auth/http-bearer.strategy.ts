import { Strategy } from 'passport-http-bearer'
import { PassportStrategy } from '@nestjs/passport'
import {
  HttpException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common'
import { AuthService } from './auth.service'

@Injectable()
export class HttpBearerStrategy extends PassportStrategy(Strategy) {
  constructor(private authService: AuthService) {
    super()
  }

  async validate(
    token: string,
    done: (error: HttpException | null, value: boolean | any) => any,
  ): Promise<any> {
    const user = await this.authService.userFromToken(token)
    if (!user) {
      done(new UnauthorizedException(), false)
    }
    done(null, user)
  }
}
