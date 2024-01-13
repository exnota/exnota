import { Module } from '@nestjs/common'
import { NoteModule } from '@exnota/note/note.module'
import { AuthModule } from '@exnota/auth/auth.module'
import { ConfigModule, ConfigService } from '@nestjs/config'
import { Config, ConfigKey, configSchema } from '@exnota/config'
import { TypeOrmModule } from '@nestjs/typeorm'

@Module({
  imports: [
    NoteModule,
    AuthModule,
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: configSchema,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService<Config>) => ({
        type: 'postgres',
        host: configService.get(ConfigKey.DATABASE_HOST),
        port: +configService.get(ConfigKey.DATABASE_PORT),
        database: configService.get(ConfigKey.DATABASE_DATABASE),
        username: configService.get(ConfigKey.DATABASE_USER),
        password: configService.get(ConfigKey.DATABASE_PASSWORD),
        entities: [],
        // synchronize: true,
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}
