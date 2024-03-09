# Apple

## Xcode

### Error: "Your team has no devices for which to generate a provisioning profile."

- Seemed to happen because I had a simulator selected when provisioning a profile for the first time (as I changed team).
  - When I selected a physical device, it went away.

## Log

2024-03-08

- Created an Individual developer account attached to an Apple ID distinct from my everyday
  one.
- Realised though that
  - Individual developer accounts can't add other users in a way that lets them work on apps (see below).
  - I had to change bundle ID because com.exnota.app belonged to my every day Apple ID.
  - I have to be logged in as that Apple ID on my Macbook to be allowed to build.

## App Store Connect

### Adding a developer

Cannot add a developer team member while account is individual:

> Note: If you’re enrolled as an individual and add users in App Store Connect, users receive access only to your content in App Store Connect and are not considered part of your team in the Apple Developer Program.
[Source](https://developer.apple.com/support/roles/).
