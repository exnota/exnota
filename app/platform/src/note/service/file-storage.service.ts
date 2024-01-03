import { parse as parsePath } from 'path'
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3'
import { Result, resultError, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { readFileSync } from 'node:fs'

export enum FileStorageServiceError {
  CREDENTIALS_MISSING = 'CREDENTIALS_MISSING',
  UPLOAD_ERROR = 'UPLOAD_ERROR',
}

type FileStorageServiceResult = {
  url: string
}

const BUCKET = 'exnota-userupload-v0'
const REGION = 'eu-central-1'
const METADATA_BOT_ID = 'bot_id'
const METADATA_WORKSPACE_ID = 'workspace_id'
const METADATA_OWNER_USER_ID = 'ownerUserId'

@Injectable()
export class FileStorageService {
  private readonly logger = new Logger(FileStorageService.name)

  constructor(private configService: ConfigService) {}

  async upload(
    path: string,
    notionInfo?: {
      botId: string
      workspaceId: string
      ownerUserId?: string
    },
  ): Promise<Result<FileStorageServiceResult, FileStorageServiceError>> {
    const accessKeyId = this.configService.get('S3_ACCESS_KEY_ID')
    const secretAccessKey = this.configService.get('SW_SECRET_ACCESS_KEY')
    if (
      typeof accessKeyId !== 'string' ||
      typeof secretAccessKey !== 'string' ||
      accessKeyId === '' ||
      secretAccessKey === '' ||
      accessKeyId.startsWith('DUMMY_') ||
      secretAccessKey.startsWith('DUMMY_')
    ) {
      return resultError(
        FileStorageServiceError.CREDENTIALS_MISSING,
        'Credentials not configured',
      )
    }

    const client = new S3Client({
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
      region: REGION,
    })

    const parsedPath = parsePath(path)
    const filename = parsedPath.base
    const contents = readFileSync(path)

    const metadata: Record<string, string> | undefined = notionInfo
      ? {
          [METADATA_BOT_ID]: notionInfo.botId,
          [METADATA_WORKSPACE_ID]: notionInfo.workspaceId,
        }
      : undefined
    if (metadata && notionInfo?.ownerUserId) {
      metadata[METADATA_OWNER_USER_ID] = notionInfo.ownerUserId
    }

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: filename,
      Body: contents,
      Metadata: metadata,
    })

    try {
      // Alteratively, this could be done asynchronously and in parallel using
      // this package: https://www.npmjs.com/package/@aws-sdk/lib-storage
      this.logger.log('Upload beginning...')
      const response = await client.send(command)
      this.logger.log('Upload success:', response)
      return resultOk({
        url: `https://${BUCKET}.s3.${REGION}.amazonaws.com/${filename}`,
      })
    } catch (err) {
      this.logger.error('Upload error:', err)
      return resultError(
        FileStorageServiceError.UPLOAD_ERROR,
        'Error uploading file',
        err,
      )
    }
  }
}
