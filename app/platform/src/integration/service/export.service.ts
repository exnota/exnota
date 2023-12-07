import {
  NotionAuthService,
  NotionAuthServiceError,
} from '@exnota/integration/service/notion-auth.service'
import { truncateTranscription } from '@exnota/integration/service/truncate'
import { Result, mapErrorType, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { APIErrorCode, Client, isNotionClientError } from '@notionhq/client'
import { SearchResponse } from '@notionhq/client/build/src/api-endpoints'

type NoteExport = {
  transcription: string
}

type AccessToken = {
  token: string
}

type ExportResult = {
  id: string
  url?: string
}

type Destination = {
  id: string
  type: 'page' | 'database'
}

// TODO: Can i extend some kinda 'notion api' standard errors?
export enum ExportError {
  NO_PAGES_SHARED = 'NO_PAGES_SHARED',
  NO_VALID_PAGE = 'NO_VALID_PAGE',
  AUTH_ERROR = 'AUTH_ERROR',
  UNKNOWN_NOTION_ERROR = 'UNKNOWN_NOTION_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
}

export enum AddAudioError {
  AUTH_ERROR = 'AUTH_ERROR',
  ADDING_AUDIO_ERROR = 'ADDING_AUDIO_ERROR',
  UNKNOWN_NOTION_ERROR = 'UNKNOWN_NOTION_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
}

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name)

  constructor(private notionAuthService: NotionAuthService) {}

  async export(
    note: NoteExport,
    token: AccessToken,
  ): Promise<Result<ExportResult, ExportError>> {
    this.logger.log(`Received note to export:`, note)
    const notionResult = this.notionAuthService.getClient(token)
    if (!notionResult.ok) {
      switch (notionResult.type) {
        case NotionAuthServiceError.EXNOTA_CREDENTIALS_MISSING:
          return mapErrorType(ExportError.INTERNAL_ERROR, notionResult)
      }
    }
    const notion = notionResult.value

    const destinationResult = await this.getDestinationId(notion)
    if (!destinationResult.ok) {
      return destinationResult
    }
    // TODO: Handle auth issue
    const exportResult = await this.exportInternal(
      notion,
      destinationResult.value,
      note,
    )
    if (!exportResult.ok) {
      return exportResult
    }

    return resultOk(exportResult.value)
  }

  async addAudio(
    pageId: string,
    url: string,
    token: AccessToken,
  ): Promise<Result<void, AddAudioError>> {
    const notionResult = this.notionAuthService.getClient(token)
    if (!notionResult.ok) {
      switch (notionResult.type) {
        case NotionAuthServiceError.EXNOTA_CREDENTIALS_MISSING:
          return mapErrorType(AddAudioError.INTERNAL_ERROR, notionResult)
      }
    }
    const notion = notionResult.value

    try {
      this.logger.log('Adding audio to page...')
      const result = await notion.blocks.children.append({
        block_id: pageId,
        children: [
          {
            type: 'audio',
            audio: {
              external: {
                url,
              },
            },
          },
        ],
      })
      this.logger.log('Audio added to page', result)
      return resultOk(void 0)
    } catch (e) {
      this.logger.log('Error adding audio to page', e)
      if (isNotionClientError(e)) {
        switch (e.code) {
          case APIErrorCode.Unauthorized:
            return resultError(AddAudioError.AUTH_ERROR, 'Notion auth error', e)
          default:
            return resultError(
              AddAudioError.UNKNOWN_NOTION_ERROR,
              'Unknown Notion error while adding audio',
              e,
            )
        }
      }
      return resultError(
        AddAudioError.UNKNOWN_ERROR,
        'Unknown error adding audio to page',
      )
    }
  }

  private async getDestinationId(
    notion: Client,
  ): Promise<Result<Destination, ExportError>> {
    const results: SearchResponse['results'] = []
    let cursor: string | undefined
    for (let i = 0; i < 20; i++) {
      this.logger.log(`Getting page ${i + 0} results`)
      try {
        const paginatedResults = await notion.search({
          page_size: 100,
          start_cursor: cursor,
        })
        results.push(...paginatedResults.results)
        if (!paginatedResults.has_more) {
          break
        }
        cursor = paginatedResults.next_cursor ?? undefined
      } catch (e) {
        this.logger.error('Failed to get page', e)
        if (isNotionClientError(e)) {
          switch (e.code) {
            case APIErrorCode.Unauthorized:
              return resultError(ExportError.AUTH_ERROR, 'Notion auth error')
            default:
              return resultError(
                ExportError.UNKNOWN_NOTION_ERROR,
                'Unknown Notion error while searching for page',
              )
          }
        }
        return resultError(
          ExportError.UNKNOWN_ERROR,
          'Unknown error while searching for page',
        )
      }
    }
    this.logger.log(`Number of results:`, results.length)
    if (results.length === 0) {
      return resultError(
        ExportError.NO_PAGES_SHARED,
        'No pages or databases shared',
      )
    }

    // Create a set of IDs from results
    const accessiblePages = new Set<string>()
    results.forEach((r) => accessiblePages.add(r.id))

    // Loop through results, returning first one that has a workspace as parent,
    // or a parent that isn't accessible.
    const parentMissingForIds = []
    let destination: Destination | undefined
    for (const r of results) {
      if ('parent' in r) {
        switch (r.parent.type) {
          case 'workspace':
            destination = {
              id: r.id,
              type: r.object,
            }
            break
          case 'database_id':
            const parentIdDb = r.parent.database_id
            if (!accessiblePages.has(parentIdDb)) {
              destination = {
                id: r.id,
                type: r.object,
              }
            }
            break
          case 'page_id':
            const parentIdPage = r.parent.page_id
            if (!accessiblePages.has(parentIdPage)) {
              destination = {
                id: r.id,
                type: r.object,
              }
            }
            break
          case 'block_id':
            this.logger.warn(
              'Got a block_id parent for page of this ID. What does this mean?',
              r.id,
            )
            break
        }
      } else {
        parentMissingForIds.push(r.id)
      }
    }
    if (parentMissingForIds.length) {
      this.logger.warn(
        'Parent missing for page/database IDs:',
        parentMissingForIds,
      )
    }

    if (destination) {
      return resultOk(destination)
    }
    return resultError(ExportError.NO_VALID_PAGE, 'No page found to export to')
  }

  private async exportInternal(
    notion: Client,
    destination: Destination,
    note: NoteExport,
  ): Promise<Result<ExportResult, ExportError>> {
    // TODO: Put in try/catch
    const apiResult = await notion.pages.create({
      parent:
        destination.type === 'database'
          ? {
              type: 'database_id',
              database_id: destination.id,
            }
          : {
              type: 'page_id',
              page_id: destination.id,
            },
      properties: {
        title: {
          title: [
            {
              text: {
                content: `Memo: ${truncateTranscription(note.transcription)}`,
              },
            },
          ],
        },
      },
    })
    this.logger.log('Exported to:', apiResult)
    // Result is either PageObjectResponse or PartialPageObjectResponse. Partial
    // is a subset off the full response, so here we pick an arbitrary property
    // to duck type check if it's a full response.
    if ('url' in apiResult) {
      return resultOk({ url: apiResult.url, id: apiResult.id })
    }
    this.logger.warn('No URL in response from Notion createPage')
    return resultOk({ id: apiResult.id })
  }
}
