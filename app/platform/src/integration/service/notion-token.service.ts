import { Result, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'

@Injectable()
export class NotionTokenService {
  private readonly logger = new Logger(NotionTokenService.name)

  constructor(private configService: ConfigService) {}

  async notionToken(code: string): Promise<Result<unknown>> {
    const clientId = this.configService.get('NOTION_OAUTH_CLIENT_ID')
    const clientSecret = this.configService.get('NOTION_OAUTH_CLIENT_SECRET')
    if (
      typeof clientId !== 'string' ||
      typeof clientSecret !== 'string' ||
      clientId === '' ||
      clientSecret === '' ||
      clientId.startsWith('DUMMY_') ||
      clientSecret.startsWith('DUMMY_')
    ) {
      return resultError('Credentials not configured')
    }
    const encoded = Buffer.from(`${clientId}:${clientSecret}`).toString(
      'base64',
    )

    let response: Response
    try {
      response = await fetch('https://api.notion.com/v1/oauth/token', {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Authorization: `Basic ${encoded}`,
        },
        body: JSON.stringify({
          grant_type: 'authorization_code',
          code,
          // redirect_uri: redirectUri,
        }),
      })
    } catch (e) {
      return resultError('Error communicating with Notion', e)
    }

    if (response.status !== 200) {
      return resultError('Error received from Notion')
    }

    let json: unknown
    try {
      json = response.json()
    } catch (e) {
      return resultError('Error parsing access token response', e)
    }

    this.logger.log(`Response from Notion:`, json)
    return resultOk(json)
  }
}
