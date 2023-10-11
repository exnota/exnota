import { Result, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'

type NoteExport = {
  title: string
}

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name)

  async export(note: NoteExport): Promise<Result<null>> {
    this.logger.log(`Received note to export:`, note)
    return resultOk(null)
  }
}
