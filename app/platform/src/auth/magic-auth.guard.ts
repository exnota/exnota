import { Injectable } from '@nestjs/common'
import { AuthGuard } from '@nestjs/passport'

// Used to protect the /auth/login route
// TODO: Update from 'local' to..??
@Injectable()
export class LocalAuthGuard extends AuthGuard('local') {}
