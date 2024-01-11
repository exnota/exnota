import MagicLoginStrategy from 'passport-magic-login'
import { PassportStrategy } from '@nestjs/passport'
import { Injectable, Logger, UnauthorizedException } from '@nestjs/common'
import { AuthService } from './auth.service'
import { ConfigService } from '@nestjs/config'
import { ConfigKey, Config } from '@exnota/config'

@Injectable()
export class MagicStrategy extends PassportStrategy(MagicLoginStrategy) {
  private readonly logger = new Logger(MagicStrategy.name)

  constructor(
    private configService: ConfigService<Config>,
    private authService: AuthService,
  ) {
    super({
      // Used to encrypt the authentication token. Needs to be long, unique and (duh) secret.
      secret: 'TODO: Add secret',

      // TODO: set up
      // TODO: full path?
      callbackUrl: `${configService.get(ConfigKey.BASE_URL)}/auth/magiclogin`,

      // Optional: options passed to the jwt.sign call (https://github.com/auth0/node-jsonwebtoken#jwtsignpayload-secretorprivatekey-options-callback)
      jwtOptions: {
        expiresIn: '365 days',
      },

      sendMagicLink: async (destination: any, href: any) => {
        this.logger.log(
          `Sending magic link to ${destination} with href ${href}`,
        )
        // await sendEmail({
        //   to: destination,
        //   body: `Click this link to finish logging in: https://yourcompany.com${href}`
        // })
      },

      // Once the user clicks on the magic link and verifies their login attempt,
      // you have to match their email to a user record in the database.
      // If it doesn't exist yet they are trying to sign up so you have to create a new one.
      // "payload" contains { "destination": "email" }
      // In standard passport fashion, call callback with the error as the first argument (if there was one)
      // and the user data as the second argument!
      verify: (payload: any, callback: any) => {
        callback(null, this.validate(payload))
      },
    })
  }

  // Note: This is executed *after* auth is successful. If auth fails, it won't
  // run.
  async validate(payload: { destination: string }): Promise<any> {
    const user = await this.authService.validateUserByEmail(payload.destination)
    if (!user) {
      throw new UnauthorizedException()
    }
    return user
  }
}
