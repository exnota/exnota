# Exnota mobile flutter app  <!-- omit from toc -->

- [Development principles](#development-principles)
  - [Robustness: Liberally accept external data](#robustness-liberally-accept-external-data)
  - [Robustness: Be conservative with app-initiated data mutations](#robustness-be-conservative-with-app-initiated-data-mutations)
- [Installation](#installation)
- [Running locally from VS Code](#running-locally-from-vs-code)
- [Troubleshooting/debugging](#troubleshootingdebugging)
  - [Deep link testing](#deep-link-testing)
    - [Android](#android)
    - [iOS](#ios)
  - [Simulators](#simulators)
  - [Database](#database)
  - [Build/Dependencies](#builddependencies)
    - [Kotlin version error when building an APK](#kotlin-version-error-when-building-an-apk)
- [Releasing](#releasing)
  - [Android: Install on device](#android-install-on-device)
  - [Android: Release to Play store](#android-release-to-play-store)

## Development principles

Old app version should not break on new data structures from the server!

### Robustness: Liberally accept external data

This allows more fixes and features without app updates.

E.g.

- Use flexible `fromJson` factories when working with domain objects from the backend.
  - Then also liberally persist those domain objects.
  - Then also liberally fetch those domain objects using `fromDb` factories.
- Support persisted data from previous app versions.
- Presentation layer presents whatever is persisted.

### Robustness: Be conservative with app-initiated data mutations

This minimises creating invalid or unexpected state.

E.g.

- Use strict, custom factories when making user-initiated changes to domain objects.
  - E.g. creation: `factory DomainObject.create(...)`
  - E.g. updates: `DomainObject copyWithNewStatus(Status status)`
- Don't allow updating/exporting of unknown note/capture types.

## Installation

TODO: Replace steps with dev containers.

1. [Install Flutter SDK](https://docs.flutter.dev/get-started/install/macos)
   - Extract to `~/code/lib/flutter`, such that the `bin` folder path is `~/code/lib/flutter/bin`
   - Permanently add to `PATH` by adding to `~/.zshrc`

      ```bash
      export PATH="$PATH:/Users/matt/code/lib/flutter/bin"
      ```

   - Verify with

      ```bash
      source ~/.zshrc
      which flutter
      ```

   - For iOS
     - Installing cocoapods via given instructions gave an error. Using Homebrew worked:

      ```bash
      brew install cocoapods
      ```

   - TODO: After getting an Apple Developer account: [Deploy to physical iOS devices](https://docs.flutter.dev/get-started/install/macos#deploy-to-physical-ios-devices)
   - For Android
   - It says "An x86 or x86_64 image is recommended." but this didn't allow selecting `Emulated Performance, select Hardware - GLES 2.0`, so I used an ARM image instead, to get hardware emulation.
   - To resolve `cmdline-tools component is missing` I needed to open Android Studio, go to Settings > Android SDK, and install `Android SDK Command-line Tools (latest)`

2. [Set up VS Code](https://docs.flutter.dev/get-started/editor)

- Note: When running command `Flutter: Run Flutter Doctor` I am seeing this in the Output tab, however those same warnings don't appear when running `flutter doctor -v` directly in a terminal window. I tried adding the same path to `.bashrc` as `.zshrc` but that didn't help.

  ```bash
  ! The flutter binary is not on your path. Consider adding /Users/matt/code/lib/flutter/bin to your path.
  ! The dart binary is not on your path. Consider adding /Users/matt/code/lib/flutter/bin to your path.
  ```

## Running locally from VS Code

1. Run `bootstrap.sh` to generated freezed models.
   - Or to watch for changes `dart run build_runner watch`

2. Select a device from the Status Bar, or command `Flutter: Select Device`
   - For iOS, you may need to manually open the Simulator app first.

3. Open `main.dart`.

4. Select `Start Debugging` from the top right of the editor

## Troubleshooting/debugging

### Deep link testing

[Source](https://pub.dev/packages/app_links#tests).

#### Android

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "sample://open.my.app/#/book/hello-world"
```

For App Links, you can also test it from Android Studio: Documentation.

Android 13:

- While in development, you may need to manually activate your links.
- Go to your app info/settings: Open by default > Add link > (your links should be already filled).

#### iOS

```bash
/usr/bin/xcrun simctl openurl booted "app://www.example.com/#/book/hello-world"
```

### Simulators

Android quirks

- To enable microphone:
   1. Open the simulator
   2. Click the 'More' button (three horizontal dot icon)
   3. Microphone > Enable 'Virtual microphone uses host audio input'
- Instead of `localhost` use `10.0.2.2`

iOS quirks

- Copy/paste doesn't seem to work with older iOS versions.

### Database

iOS Simulator

1. Install sqlitebrowser.org

2. Find the simulator databases

   ```bash
   find /Users/matt/Library/Developer/CoreSimulator/Devices -name "exnota.sqlite" -exec ls -al {} +
   ```

3. Copy the path of the most recently modified database, if that's what you
want, and open with

   ```bash
   open /Users/matt/Library/Developer/CoreSimulator/Devices/...etc.../exnota.sqlite
   ```

Android Simulator

1. Install adb

   ```bash
   brew install android-platform-tools
   ```

2. Configure adb to use root, to avoid permission error trying to access
database:

   ```bash
   adb root
   ```

3. Download database file to current directory

   ```bash
   adb pull /data/data/com.exnota.app/app_flutter/exnota.sqlite
   ```

   - If that path isn't correct, you can find the correct one:

      ```bash
      adb devices # find the relevant device
      adb -s emulator-5554 shell # connect to device
      ```

      You should now be connected to shell and can search for the location.

### Build/Dependencies

#### Kotlin version error when building an APK

```bash
Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is 1.8.0, expected version is 1.6.0
```

[Explanation](https://stackoverflow.com/a/74425347). Following [these steps](https://stackoverflow.com/a/72984766)
resolved the issue without guesswork, though it requires waiting for a lot to
download:

1. Open Android Studio
2. Right click the `android` folder
3. Select: Flutter > Open in Android Studio
4. Wait a while for it to load
5. It'll ask in a notification if you want to run a process to upgrade Gradle.
6. Click Yes
7. Use the version of Gradle it suggests
8. After done, run `flutter clean`

## Releasing

### Android: Install on device

<https://docs.flutter.dev/deployment/android#install-an-apk-on-a-device>

1. `flutter build apk`
2. `flutter install`

### Android: Release to Play store

1. Download keystore `upload-keystore.jks` from secure location.

2. Place in `/app/mobile/android/app`. Don't change the filename.
   - .gitignore should prevent this from being committed.

3. Duplicate `android/key.properties.template`, renaming to `key.properties`
   - .gitignore should prevent this from being committed.

4. Update both `storePassword` and `keyPassword` in the file to the keystore
password. Both are the same password.

5. Bump version in `pubspec.yaml`.

6. Run `flutter build appbundle`
