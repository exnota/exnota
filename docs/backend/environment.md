# Environment

## Renaming or creating a new environment

1. Add domain to Notion OAuth
   - See [notion.md](notion.md#add-oauth-redirect-url)

2. Add domain to Google Auth
   - Google Cloud > APIs and Services > Credentials > OAuth 2.0 Client IDs > Exnota Backend > Authorised redirect URIs ([link]<https://console.cloud.google.com/apis/credentials/oauthclient/504406502751-059e7qpe5tav9i59km97m70df25l2nf3.apps.googleusercontent.com?organizationId=0&project=exnota>)

3. Update application URL in the settings UI
   - E.g. <http://localhost:8080/_/#/settings>
   - This is used in code.

4. Disable collection modifications in shared environments (prod, staging)
   - In settings UI, enable `Hide collection create and edit controls`

5. Configure logging
   - Go to: Logs (left menu) > Select cog icon
   - Turn off `Enable IP logging`
   - Set a higher logs retention