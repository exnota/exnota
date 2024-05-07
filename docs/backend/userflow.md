# Userflow

## User auth

### Getting an Exnota token

1. Choose a user who has username/password
2. Call with user/pass {{baseUrl}}/collections/user/auth-with-password HTTP/1.1
3. Use token returned

## Notion auth

1. Get a request code URL: {{baseUrl}}/exnota/integration/notion/mobile-code-request-path
2. Open Dev Tools > Network and capture the code on redirect
3. Create or update an integration with config

    ```json
    {
        "auth": "<code>"
    }
    ```

### Possible UI flows

Authorizing Exnota to use Notion should succeed in all these cases:

a. Auth completed with Exnota still on setup screen.
    1. notion.so auth page opened.
    2. Complete auth.
b. Auth complete when Exnota no longer on setup screen.
    1. notion.so auth page opened.
    2. Navigate back to Exnota.
    3. Change screen.
    4. Go back to notion.so auth page and complete.
c. Auth completed when Exnota is closed.
    1. notion.so auth page opened.
    2. Close Exnota.
    3. Go back to notion.so auth page and complete.

## Removing Notion auth

1. In Notion: Settings & Members > My Connections > (three dots) > Disconnect Account
2. Call verify endpoint with integration ID: GET {{baseUrl}}/exnota/integration/verify-access
3.
