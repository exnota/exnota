# Local

## Run using simulator or connected device

1. Run `flutter pub get` to get dependencies.

2. Run `bootstrap.sh` to generated freezed models.
   - Or to watch for changes `dart run build_runner watch`

3. Select a device from the Status Bar, or command `Flutter: Select Device`
   - For iOS, you may need to manually open the Simulator app first.

4. Select `Start Debugging` from the top right of the editor
   - If the iOS simulator is not started, you'll need to start it then repeat to select it as the device to be used.

## Troubleshooting/debugging

### App localization compile errors

Solution: Run `flutter run` before attempting VS Code launch config.

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

#### Getting files

Android:

- Android Studio > View > Tool Windows > Device File Explorer

- Use `run-as` inside the simulator to avoid a permission denied error:

   ```bash
   # Explore files
   adb shell
   emu64a:/ $ run-as com.exnota.app ls /data/user/0/com.exnota.app/app_flutter/exnota/notes/audio/                                                   
   block-test-1710293021774.wav  block-test-1710293196714.wav  block-test-1710293294715.wav  block-test-1710293894276.wav
   emu64a:/ $ 

   # Copy a file from simulator to host
   adb shell "run-as com.exnota.app cat /data/user/0/com.exnota.app/app_flutter/exnota/notes/audio/block-test-1710293294715.wav" > file.wav
   ```

iOS:

- Should be able to open them directly on host system (i.e. your Mac). Path will be something like `/Users/matt/Library/Developer/CoreSimulator/Devices/...`

#### Android quirks

- To enable microphone:
   1. Open the simulator
   2. Click the 'More' button (three horizontal dot icon)
   3. Microphone > Enable 'Virtual microphone uses host audio input'
- Instead of `localhost` use `10.0.2.2`

#### iOS quirks

- Copy/paste doesn't seem to work with older iOS versions.

### Database

iOS Simulator

1. Install sqlitebrowser.org

2. Copy path of the first DB file from this command:

   ```bash
   # List database files, most recently modified first
   find /Users/matt/Library/Developer/CoreSimulator/Devices -name "exnota.sqlite" -exec ls -alt {} +
   ```

3. Open the file, which can be done via termainal easily:

   ```bash
   open <copied filepath>

   # E.g.
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
