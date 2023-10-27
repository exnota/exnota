import { parse as parsePath } from 'path'
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3'
import { resultError } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { readFileSync } from 'node:fs'

enum FileStorageServiceError {
  CREDENTIALS_MISSING,
}

@Injectable()
export class FileStorageService {
  private readonly logger = new Logger(FileStorageService.name)
  constructor(private configService: ConfigService) {}
  async upload(path: string) {
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
      region: 'eu-central-1',
    })

    const parsedPath = parsePath(path)
    const contents = readFileSync(path)
    const command = new PutObjectCommand({
      Bucket: 'exnota-userupload-v0',
      Key: parsedPath.base,
      Body: contents,
    })

    try {
      // Alteratively, this could be done asynchronously and in parallel using
      // this package: https://www.npmjs.com/package/@aws-sdk/lib-storage
      const response = await client.send(command)
      console.log(response)
    } catch (err) {
      console.error(err)
    }
  }
}
