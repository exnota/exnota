import { Injectable } from '@nestjs/common'
import { AuthGuard } from '@nestjs/passport'

// Used to protect all routes but /auth/login, because at that point the user
// does not have a JWT.
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
