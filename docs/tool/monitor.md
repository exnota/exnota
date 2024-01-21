# Monitoring

## Setup

### Receiving notifications

1. Install Telegram
2. Use this bot to create a notifications bot: <https://t.me/BotFather>
3. Save the details to the secrets vault.
4. Send a message to the new bot to initialize it.
5. Setup notifications in Kuma to send to this bot.
   * Use the 'Test' button to ensure the notification works and is audible on desktop and mobile.
   * On Android, you can flag specific conversations as priority, and flag priority conversations as being allowed to override do not disturb settings.
     * This may be the only way to do it actually. Setting Telegram to override Do Not Disturb didn't seem to work once Android had flagged a notification as a conversation. Only once I set it up like this did it actually override it. Another option may be to flag a notification as not being a conversation, which is an Android option too.

### Monitoring app

1. Install fly.io CLI <https://fly.io/launchpad>
   * Edit the default settings, which include 1 GB ram. I think that will cost money.
2. Add a volume/mount.
3. Edit `fly.toml` so `internal_port` is `3001`
