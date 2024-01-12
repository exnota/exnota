import { AccountService } from '@exnota/account/account.service'
import { Injectable, UnauthorizedException } from '@nestjs/common'
import * as crypto from 'crypto'

@Injectable()
export class AuthService {
  constructor(private accountService: AccountService) {}

  async validateUserByEmail(email: string): Promise<any> {
    const user = await this.accountService.findByEmail(email)
    if (!user) {
      throw new UnauthorizedException()
    }

    return user
  }

  generateToken(userId: string): string {
    const token = crypto.randomBytes(32).toString('hex')
    this.accountService.saveToken({ userId, token })
    return token
  }

  userFromToken(token: string): any {
    return this.accountService.findByToken(token)
  }
}
