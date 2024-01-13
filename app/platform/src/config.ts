import * as Joi from 'joi'

// Used to request environment variables
export enum ConfigKey {
  // Environment specific: Config
  BASE_URL = 'BASE_URL',
  PATH_UPLOAD_AUDIO = 'PATH_UPLOAD_AUDIO',

  // Environment specific: Database source
  DATABASE_HOST = 'DATABASE_HOST',
  DATABASE_PORT = 'DATABASE_PORT',

  // Environment specific: Database credentials (see relevant vault)
  DATABASE_DATABASE = 'DATABASE_DATABASE',
  DATABASE_USER = 'DATABASE_USER',
  DATABASE_PASSWORD = 'DATABASE_PASSWORD',

  // Environment specific: Internal keys (see relevant vault)
  MAGIC_LINK_SECRET = 'MAGIC_LINK_SECRET',

  // Notion: Auth
  NOTION_OAUTH_CLIENT_ID = 'NOTION_OAUTH_CLIENT_ID',
  NOTION_OAUTH_CLIENT_SECRET = 'NOTION_OAUTH_CLIENT_SECRET',

  // Notion: App Store credentials
  NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET = 'NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET',
  NOTION_PLAY_CONSOLE_SECRET = 'NOTION_PLAY_CONSOLE_SECRET',

  // Notion: If requests match this, extra test data is saved
  NOTION_TEST_WORKSPACE_ID = 'NOTION_TEST_WORKSPACE_ID',
  NOTION_TEST_BOT_ID = 'NOTION_TEST_BOT_ID',
  NOTION_TEST_OWNER_USER_ID = 'NOTION_TEST_OWNER_USER_ID',

  // Other third-party keys
  S3_ACCESS_KEY_ID = 'S3_ACCESS_KEY_ID',
  SW_SECRET_ACCESS_KEY = 'SW_SECRET_ACCESS_KEY',
  OPENAI_KEY = 'OPENAI_KEY',
  SENDGRID_FROM_EMAIL = 'SENDGRID_FROM_EMAIL',
  SENDGRID_API_KEY = 'SENDGRID_API_KEY',
}

// Used to type the config service when injecting it
export type Config = {
  // Environment specific: Config
  [ConfigKey.BASE_URL]: string
  [ConfigKey.PATH_UPLOAD_AUDIO]: string

  // Environment specific: Database source
  [ConfigKey.DATABASE_HOST]: string
  [ConfigKey.DATABASE_PORT]: string

  // Environment specific: Database credentials (see relevant vault)
  [ConfigKey.DATABASE_DATABASE]: string
  [ConfigKey.DATABASE_USER]: string
  [ConfigKey.DATABASE_PASSWORD]: string

  // Environment specific: Internal keys (see relevant vault)
  [ConfigKey.MAGIC_LINK_SECRET]: string

  // Notion: Auth
  [ConfigKey.NOTION_OAUTH_CLIENT_ID]: string
  [ConfigKey.NOTION_OAUTH_CLIENT_SECRET]: string

  // Notion: App Store credentials
  [ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET]: string
  [ConfigKey.NOTION_PLAY_CONSOLE_SECRET]: string

  // Notion: If requests match this, extra test data is saved
  [ConfigKey.NOTION_TEST_WORKSPACE_ID]: string
  [ConfigKey.NOTION_TEST_BOT_ID]: string
  [ConfigKey.NOTION_TEST_OWNER_USER_ID]: string

  // Other third-party keys
  [ConfigKey.S3_ACCESS_KEY_ID]: string
  [ConfigKey.SW_SECRET_ACCESS_KEY]: string
  [ConfigKey.OPENAI_KEY]: string
  [ConfigKey.SENDGRID_FROM_EMAIL]: string
  [ConfigKey.SENDGRID_API_KEY]: string
}

// Should be safe to re-use this: https://github.com/hapijs/joi/issues/850
const requiredString = Joi.string()
  .required()
  // Catch when an environment variable has been copied from .env.template
  // without having its DUMMY_ prefixed value updated
  .pattern(/^DUMMY_/, {
    invert: true,
  })

export const PATH_UPLOAD_AUDIO = '/tmp/upload/audio'

// Used to validate required environment variables from .env
export const configSchema = Joi.object<Config>({
  // Environment specific: Config
  [ConfigKey.BASE_URL]: requiredString,
  [ConfigKey.PATH_UPLOAD_AUDIO]: Joi.string().default(PATH_UPLOAD_AUDIO),

  // Environment specific: Database source
  [ConfigKey.DATABASE_HOST]: requiredString,
  [ConfigKey.DATABASE_PORT]: requiredString,

  // Environment specific: Database credentials (see relevant vault)
  [ConfigKey.DATABASE_DATABASE]: requiredString,
  [ConfigKey.DATABASE_USER]: requiredString,
  [ConfigKey.DATABASE_PASSWORD]: requiredString,

  // Environment specific: Internal keys (see relevant vault)
  [ConfigKey.MAGIC_LINK_SECRET]: requiredString,

  // Notion: Auth
  [ConfigKey.NOTION_OAUTH_CLIENT_ID]: requiredString,
  [ConfigKey.NOTION_OAUTH_CLIENT_SECRET]: requiredString,

  // Notion: App Store credentials
  [ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET]:
    requiredString,
  [ConfigKey.NOTION_PLAY_CONSOLE_SECRET]: requiredString,

  // Notion: If requests match this, extra test data is saved
  [ConfigKey.NOTION_TEST_WORKSPACE_ID]: requiredString,
  [ConfigKey.NOTION_TEST_BOT_ID]: requiredString,
  [ConfigKey.NOTION_TEST_OWNER_USER_ID]: requiredString,

  // Other third-party keys
  [ConfigKey.S3_ACCESS_KEY_ID]: requiredString,
  [ConfigKey.SW_SECRET_ACCESS_KEY]: requiredString,
  [ConfigKey.OPENAI_KEY]: requiredString,
  [ConfigKey.SENDGRID_FROM_EMAIL]: requiredString,
  [ConfigKey.SENDGRID_API_KEY]: requiredString,
})
