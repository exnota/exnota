# Install

## Android: Install on physical device

<https://docs.flutter.dev/deployment/android#install-an-apk-on-a-device>

1. `flutter build apk`
2. `flutter install`

## iOS: Install on physical device

Apparently need to get it working in Xcode first, then should be able to debug in VS Code ([link](https://stackoverflow.com/questions/54444538/how-do-i-run-test-my-flutter-app-on-a-real-device)).

<https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device>

1. Open project in Xcode
   - In the root `mobile` folder: `open ios/Runner.xcworkspace`
2. First time: Ensure each project is assigned to a team: <https://help.apple.com/xcode/mac/current/#/dev23aab79b4>
3. In breadcrumbs at top of Xcode UI, ensure it says `Runner > [Desired device]`
4. Click the play button, top left.

This will install in debug mode and cannot be opened when disconnected from
Xcode.

To run from VS Code, use the same steps as for Android. Breakpoints should work.

### Viewing logs in Xcode

1. In Xcode, go to Report Navigator (left sidebar, furthest icon on right).
2. Select 'Console' under the currently running build (should have a spinner)

Bottom right panel seems to have the live log feed.

### Troubleshooting

#### 'Untrusted Developer' error

1. Settings > General > Device Management/VPN & Device Management, and select to trust
2. Then try building in Xcode again.

#### "codesign wants to access keychain (key chain)..." error

- Enter your computer's user password and select `Always allow`!
- `Always allow` is important, otherwise it will keep asking, which makes it
   seem like the password is wrong.

#### From VS Code, if you get: `“iproxy” cannot be opened because the developer cannot be verified.`

Try `rm -rf /Users/matt/code/lib/flutter/bin/cache/artifacts` (replace user name)

### Install a release version / Use without Xcode

To use the non-debug version and be able to use the app without being connected
to Xcode:

1. Select `Runner` in the breadcrums at the top of Xcode UI
2. Select `Edit scheme`.
   - A window should open with the `Run` tab focused.
3. Change `Build configuration` from `Debug` to `Release`.
4. Click the play button.
