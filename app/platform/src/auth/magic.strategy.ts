import MagicLoginStrategy from 'passport-magic-login'
import { PassportStrategy } from '@nestjs/passport'
import { Injectable, Logger } from '@nestjs/common'
import { AuthService } from './auth.service'
import { ConfigService } from '@nestjs/config'
import { ConfigKey, Config } from '@exnota/config'

@Injectable()
export class MagicStrategy extends PassportStrategy(MagicLoginStrategy) {
  private readonly logger = new Logger(MagicStrategy.name)

  constructor(
    configService: ConfigService<Config>,
    private authService: AuthService,
  ) {
    super({
      // Used to encrypt the authentication token. Needs to be long, unique and (duh) secret.
      secret: configService.get(ConfigKey.MAGIC_LINK_SECRET),

      callbackUrl: `${configService.get(
        ConfigKey.BASE_URL,
      )}/auth/magic-success`,

      // Options passed to the jwt.sign call (https://github.com/auth0/node-jsonwebtoken#jwtsignpayload-secretorprivatekey-options-callback)
      jwtOptions: {
        // How long the magic link is valid for.
        expiresIn: '10 minutes',
      },

      // eslint-disable-next-line require-await
      sendMagicLink: async (destination: any, href: any) => {
        this.logger.log(
          `Sending magic link to ${destination} with href ${href}`,
        )
      },

      // Callback should be called with the error as the first argument (if there was one)
      // and the user data as the second argument!
      verify: (payload: any, callback: any) => {
        callback(null, this.validate(payload))
      },
    })
  }

  async validate(payload: { destination: string }): Promise<any> {
    return await this.authService.validateUserByEmail(payload.destination)
  }
}
