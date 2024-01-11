import * as Joi from 'joi'

// Used to request environment variables
export enum ConfigKey {
  // Base
  BASE_URL = 'BASE_URL',
  PATH_UPLOAD_AUDIO = 'PATH_UPLOAD_AUDIO',

  // Integration module
  NOTION_OAUTH_CLIENT_ID = 'NOTION_OAUTH_CLIENT_ID',
  NOTION_OAUTH_CLIENT_SECRET = 'NOTION_OAUTH_CLIENT_SECRET',
  NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET = 'NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET',
  NOTION_PLAY_CONSOLE_SECRET = 'NOTION_PLAY_CONSOLE_SECRET',
  // These can be personal or test details
  NOTION_TEST_WORKSPACE_ID = 'NOTION_TEST_WORKSPACE_ID',
  NOTION_TEST_BOT_ID = 'NOTION_TEST_BOT_ID',
  NOTION_TEST_OWNER_USER_ID = 'NOTION_TEST_OWNER_USER_ID',

  // Note module
  S3_ACCESS_KEY_ID = 'S3_ACCESS_KEY_ID',
  SW_SECRET_ACCESS_KEY = 'SW_SECRET_ACCESS_KEY',
  OPENAI_KEY = 'OPENAI_KEY',

  // Message module
  SENDGRID_FROM_EMAIL = 'SENDGRID_FROM_EMAIL',
  SENDGRID_API_KEY = 'SENDGRID_API_KEY',
}

// Used to type the config service when injecting it
export type Config = {
  // Base
  [ConfigKey.BASE_URL]: string
  [ConfigKey.PATH_UPLOAD_AUDIO]: string

  // Integration module
  [ConfigKey.NOTION_OAUTH_CLIENT_ID]: string
  [ConfigKey.NOTION_OAUTH_CLIENT_SECRET]: string
  [ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET]: string
  [ConfigKey.NOTION_PLAY_CONSOLE_SECRET]: string
  // These can be personal or test details
  [ConfigKey.NOTION_TEST_WORKSPACE_ID]: string
  [ConfigKey.NOTION_TEST_BOT_ID]: string
  [ConfigKey.NOTION_TEST_OWNER_USER_ID]: string

  // Note module
  [ConfigKey.S3_ACCESS_KEY_ID]: string
  [ConfigKey.SW_SECRET_ACCESS_KEY]: string
  [ConfigKey.OPENAI_KEY]: string

  // Message module
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
  // Base
  [ConfigKey.BASE_URL]: requiredString,
  [ConfigKey.PATH_UPLOAD_AUDIO]: Joi.string().default(PATH_UPLOAD_AUDIO),

  // Integration module
  [ConfigKey.NOTION_OAUTH_CLIENT_ID]: requiredString,
  [ConfigKey.NOTION_OAUTH_CLIENT_SECRET]: requiredString,
  [ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET]:
    requiredString,
  [ConfigKey.NOTION_PLAY_CONSOLE_SECRET]: requiredString,
  // These can be personal or test details
  [ConfigKey.NOTION_TEST_WORKSPACE_ID]: requiredString,
  [ConfigKey.NOTION_TEST_BOT_ID]: requiredString,
  [ConfigKey.NOTION_TEST_OWNER_USER_ID]: requiredString,

  // Note module
  [ConfigKey.S3_ACCESS_KEY_ID]: requiredString,
  [ConfigKey.SW_SECRET_ACCESS_KEY]: requiredString,
  [ConfigKey.OPENAI_KEY]: requiredString,

  // Message module
  [ConfigKey.SENDGRID_FROM_EMAIL]: requiredString,
  [ConfigKey.SENDGRID_API_KEY]: requiredString,
})
