# Google Sign-in

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
