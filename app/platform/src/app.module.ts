import { Module } from '@nestjs/common'
import { NoteModule } from '@exnota/note/note.module'
import { AuthModule } from '@exnota/auth/auth.module'

@Module({
  imports: [NoteModule, AuthModule],
})
export class AppModule {}
