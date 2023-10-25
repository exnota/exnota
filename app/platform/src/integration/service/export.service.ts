import { Result, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { Client } from '@notionhq/client'
import { SearchResponse } from '@notionhq/client/build/src/api-endpoints'

type NoteExport = {
  title: string
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

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name)

  async export(
    note: NoteExport,
    token: AccessToken,
  ): Promise<Result<ExportResult>> {
    this.logger.log(`Received note to export:`, note)
    const notion = new Client({
      auth: token.token,
    })
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

  private async getDestinationId(notion: Client): Promise<Result<Destination>> {
    const results: SearchResponse['results'] = []
    let cursor: string | undefined
    for (let i = 0; i < 20; i++) {
      this.logger.log(`Getting page ${i + 0} results`)
      const paginatedResults = await notion.search({
        page_size: 100,
        start_cursor: cursor,
      })
      results.push(...paginatedResults.results)
      if (!paginatedResults.has_more) {
        break
      }
      cursor = paginatedResults.next_cursor ?? undefined
    }
    this.logger.log(`Results:`, results)
    if (results.length === 0) {
      return resultError('No pages or databases shared')
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
    return resultError('No page found to export to')
  }

  private async exportInternal(
    notion: Client,
    destination: Destination,
    note: NoteExport,
  ): Promise<Result<ExportResult>> {
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
                content: `Memo: ${note.title}`,
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
