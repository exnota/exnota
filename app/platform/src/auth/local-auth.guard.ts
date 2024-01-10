import { Injectable } from '@nestjs/common'
import { AuthGuard } from '@nestjs/passport'

// Used to protect the /auth/login route
@Injectable()
export class LocalAuthGuard extends AuthGuard('local') {}
