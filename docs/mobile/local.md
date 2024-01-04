# Local

## Run using simulator or connected device

1. Run `flutter pub get` to get dependencies.

2. Run `bootstrap.sh` to generated freezed models.
   - Or to watch for changes `dart run build_runner watch`

3. Select a device from the Status Bar, or command `Flutter: Select Device`
   - For iOS, you may need to manually open the Simulator app first.

4. Open `main.dart`.

5. Select `Start Debugging` from the top right of the editor

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
