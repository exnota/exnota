import { Result, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { Client } from '@notionhq/client'

type AccessToken = {
  token: string
}

export enum NotionAuthServiceError {
  EXNOTA_CREDENTIALS_MISSING = 'EXNOTA_CREDENTIALS_MISSING',
}

@Injectable()
export class NotionAuthService {
  private readonly logger = new Logger(NotionAuthService.name)

  constructor(private configService: ConfigService) {}

  getClient(token: AccessToken): Result<Client, NotionAuthServiceError> {
    const result = this.getSecrets()
    if (!result.ok) {
      return result
    }

    if (token.token === result.value.playConsoleAccessTokenTriggeringSecret) {
      this.logger.log('Using Play Console auth')
      return resultOk(
        new Client({
          auth: result.value.playConsoleSecret,
        }),
      )
    }

    return resultOk(
      new Client({
        auth: token.token,
      }),
    )
  }

  private getSecrets(): Result<
    {
      playConsoleSecret: string
      playConsoleAccessTokenTriggeringSecret: string
    },
    NotionAuthServiceError
  > {
    const playConsoleSecret = this.configService.get(
      'NOTION_PLAY_CONSOLE_SECRET',
    )
    const playConsoleAccessTokenTriggeringSecret = this.configService.get(
      'NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET',
    )
    if (
      typeof playConsoleSecret !== 'string' ||
      typeof playConsoleAccessTokenTriggeringSecret !== 'string' ||
      playConsoleSecret === '' ||
      playConsoleAccessTokenTriggeringSecret === '' ||
      playConsoleSecret.startsWith('DUMMY_') ||
      playConsoleAccessTokenTriggeringSecret.startsWith('DUMMY_')
    ) {
      return resultError(
        NotionAuthServiceError.EXNOTA_CREDENTIALS_MISSING,
        'Credentials not configured',
      )
    }
    return resultOk({
      playConsoleSecret,
      playConsoleAccessTokenTriggeringSecret,
    })
  }
}
