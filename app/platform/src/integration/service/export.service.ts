import { Result, resultOk } from '@exnota/lib/result'
import { Injectable, Logger } from '@nestjs/common'

type NoteExport = {
  title: string
  accessToken: string
}

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name)

  async export(note: NoteExport): Promise<Result<null>> {
    this.logger.log(`Received note to export:`, note)
    return resultOk(null)
  }
}
