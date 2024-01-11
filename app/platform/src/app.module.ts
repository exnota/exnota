import { Module } from '@nestjs/common'
import { NoteModule } from '@exnota/note/note.module'
import { AuthModule } from '@exnota/auth/auth.module'
import { ConfigModule } from '@nestjs/config'
import { configSchema } from '@exnota/config'

@Module({
  imports: [
    NoteModule,
    AuthModule,
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: configSchema,
    }),
  ],
})
export class AppModule {}
