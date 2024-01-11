import { Config, ConfigKey } from '@exnota/config'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { Client } from '@notionhq/client'

type AccessToken = {
  token: string
}

@Injectable()
export class NotionAuthService {
  private readonly logger = new Logger(NotionAuthService.name)

  constructor(private configService: ConfigService<Config>) {}

  getClient(token: AccessToken): Client {
    const secrets = this.getSecrets()

    if (token.token === secrets.playConsoleAccessTokenTriggeringSecret) {
      this.logger.log('Using Play Console auth')
      return new Client({
        auth: secrets.playConsoleSecret,
      })
    }

    return new Client({
      auth: token.token,
    })
  }

  private getSecrets(): {
    playConsoleSecret: string
    playConsoleAccessTokenTriggeringSecret: string
  } {
    const playConsoleSecret = this.configService.get(
      ConfigKey.NOTION_PLAY_CONSOLE_SECRET,
    )
    const playConsoleAccessTokenTriggeringSecret = this.configService.get(
      ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET,
    )
    return {
      playConsoleSecret,
      playConsoleAccessTokenTriggeringSecret,
    }
  }
}
