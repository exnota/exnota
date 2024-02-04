# Google Sign-in

## Add credentials to Pocketbase

1. Get credentials:
   1. Open vault entry 'Exnota Backend OAuth Google credentials link`
   2. Open the URL
   3. The client ID and client secret should both be on this page.
2. Add them to Pocketbase: `Settings > Auth Providers > Google`

## Create credentials

<https://medium.com/codebrew/flutter-google-sign-in-without-firebase-3680713966fb>

1. Prep: User support email - required
   * This can either be the primary email for a Google account, or a Google Group. You can't use a Google account's alternative email. All the support, etc. threads describing how to add a different email don't work. So it's simplest to create a Google Group for this.
   * Google group troubleshooting
     * Google Admin > Apps > Google Workspace > Groups for Business: Ensure it's turned on, and configured correctly. If it's off, no groups appear in groups.google.com.
     * Configure the group at groups.google.com.
     * Group emails may go to 'Pending' by default and no email is sent, so when configuring, make sure to set spam emails to be posted anyway.
2. Create project in Google Cloud, and create credentials for it
3. [APIs and Services > Credentials](https://console.cloud.google.com/apis/credentials?referrer=search&organizationId=0&project=exnota) > Create Credentials > OAuth Client ID
   * May need to first setup the Consent screen
     * Privacy policy can be blank while in Testing status.
     * Don't add Scopes.
     * Add test users.
   * Select Web Application for Pocketbase (and other backends that handle the auth). Selecting Android App won't provide a secret; Presumably it performs some verification of the app itself.

## Add testers

Warning: As of writing, this hasn't actually worked yet. I've only been able to login using my Google account associated with the developer account. When I use an account added to the email list, it gives an error with some detail.

1. Play Console > Select Exnota on dashboard > Testing > Internal Testing ([link](https://play.google.com/console/u/0/developers/6387004654681121800/app/4973901296159773541/tracks/internal-testing))
2. Select Testers tab
3. Add to email list (maybe can also copy link and send that?)
