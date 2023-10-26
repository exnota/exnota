import { Result, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'

export enum NotionTokenServiceError {
  NOTION_AUTH_ERROR = 'NOTION_AUTH_ERROR',
  EXNOTA_CREDENTILS_MISSING = 'EXNOTA_CREDENTILS_MISSING',
}

@Injectable()
export class NotionTokenService {
  private readonly logger = new Logger(NotionTokenService.name)

  constructor(private configService: ConfigService) {}

  async notionToken(
    code: string,
  ): Promise<Result<unknown, NotionTokenServiceError>> {
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
      return resultError(
        NotionTokenServiceError.EXNOTA_CREDENTILS_MISSING,
        'Credentials not configured',
      )
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
          // redirect_uri must match what the app sends for a code grant.
          redirect_uri:
            'https://exnota.com/api/integration/notion/mobile-code-redirect',
        }),
      })
    } catch (e) {
      return resultError(
        NotionTokenServiceError.NOTION_AUTH_ERROR,
        'Error communicating with Notion',
        e,
      )
    }

    let json: unknown
    try {
      json = await response.json()
    } catch (e) {
      this.logger.error('Error parsing access token response', {
        status: response.status,
        statusText: response.statusText,
      })
      return resultError(
        NotionTokenServiceError.NOTION_AUTH_ERROR,
        'Error parsing access token response',
        e,
      )
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
          NotionTokenServiceError.NOTION_AUTH_ERROR,
          `Received ${response.status} error '${error}' from Notion with description '${description}'`,
        )
      }
      return resultError(
        NotionTokenServiceError.NOTION_AUTH_ERROR,
        'Received error from Notion',
      )
    }

    this.logger.log(`Response from Notion:`, json)
    return resultOk(json)
  }
}
