import { ConfigKey, configSchema } from '@exnota/config'

describe('configSchema', () => {
  describe('Given a config with all required keys', () => {
    let config: any
    beforeEach(() => {
      config = {
        [ConfigKey.BASE_URL]: 'https://example.com',
        [ConfigKey.NOTION_OAUTH_CLIENT_ID]: 'abc',
        [ConfigKey.NOTION_OAUTH_CLIENT_SECRET]: 'def',
        [ConfigKey.NOTION_PLAY_CONSOLE_ACCESS_TOKEN_TRIGGERING_SECRET]: 'ghi',
        [ConfigKey.NOTION_PLAY_CONSOLE_SECRET]: 'jkl',
        [ConfigKey.NOTION_TEST_WORKSPACE_ID]: 'mno',
        [ConfigKey.NOTION_TEST_BOT_ID]: 'pqr',
        [ConfigKey.NOTION_TEST_OWNER_USER_ID]: 'stu',
        [ConfigKey.S3_ACCESS_KEY_ID]: 'vwx',
        [ConfigKey.SW_SECRET_ACCESS_KEY]: 'yz',
        [ConfigKey.OPENAI_KEY]: '123',
        [ConfigKey.SENDGRID_FROM_EMAIL]: '456',
        [ConfigKey.SENDGRID_API_KEY]: '789',
      }
    })
    describe('When unchanged', () => {
      test('Then it should be valid', () => {
        const result = configSchema.validate(config)
        expect(result.error).toBeUndefined()
      })
    })
    describe('When a key still has a "DUMMY_" prefix', () => {
      test('Then it should be invalid', () => {
        config[ConfigKey.NOTION_OAUTH_CLIENT_ID] = 'DUMMY_abc'
        const result = configSchema.validate(config)
        expect(result.error).toBeDefined()
      })
    })
  })
})
