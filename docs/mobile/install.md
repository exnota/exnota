# Install

## Android: Install on physical device

<https://docs.flutter.dev/deployment/android#install-an-apk-on-a-device>

1. `flutter build apk`
2. `flutter install`

## iOS: Install on physical device (some duplication with ./debug.md)

<https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device>

1. In the root `mobile` folder: `open ios/Runner.xcworkspace`
2. In breadcrumbs at top of Xcode UI, ensure it says `Runner > [Desired device]`
3. Click the play button, top left.
4. You may get "codesign wants to access key chain..."
   - Enter your computer's user password and select `Always allow`!
   - `Always allow` is important, otherwise it will keep asking, which makes it
      seem like the password is wrong.
5. You may get an 'untrusted developer' error
   - Trust developer by going to `Settings > General > Device Management` and
   selecting the profile to trust

This will install in debug mode and cannot be opened when disconnected from
Xcode.

### Install a release version / Use without Xcode

To use the non-debug version and be able to use the app without being connected
to Xcode:

1. Select `Runner` in the breadcrums at the top of Xcode UI
2. Select `Edit scheme`.
   - A window should open with the `Run` tab focused.
3. Change `Build configuration` from `Debug` to `Release`.
4. Click the play button.
