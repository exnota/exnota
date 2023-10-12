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
          redirect_uri: 'https://exnota.com',
        }),
      })
    } catch (e) {
      return resultError('Error communicating with Notion', e)
    }

    let json: unknown
    try {
      json = await response.json()
    } catch (e) {
      this.logger.error('Error parsing access token response', {
        status: response.status,
        statusText: response.statusText,
      })
      return resultError('Error parsing access token response', e)
    }

    if (response.status !== 200) {
      if (typeof json === 'object' && json !== null) {
        const error = 'error' in json ? json.error : ''
        const description =
          'error_description' in json ? json.error_description : ''
        const requestId = 'request_id' in json ? json.request_id : ''

        this.logger.error(`Received error from Notion:`, {
          ...json,
          requestId,
          status: response.status,
          statusText: response.statusText,
        })
        return resultError(
          `Received ${response.status} error '${error}' from Notion with description '${description}'`,
        )
      }
      return resultError('Received error from Notion')
    }

    this.logger.log(`Response from Notion:`, json)
    return resultOk(json)
  }
}
