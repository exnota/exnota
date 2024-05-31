# Environment

## Renaming or creating a new environment

1. Add domain to Notion OAuth
   - See [notion.md](notion.md#add-oauth-redirect-url)

2. Update application URL in the settings UI
   - E.g. <http://localhost:8080/_/#/settings>
   - This is used in code.

3. Disable collection modifications in shared environments (prod, staging)
   - In settings UI, enable `Hide collection create and edit controls`
