# Exnota mobile flutter app

## Installation

TODO: Replace steps with dev containers.

1. [Install Flutter SDK](https://docs.flutter.dev/get-started/install/macos)
   * Extract to `~/code/lib/flutter`, such that the `bin` folder path is `~/code/lib/flutter/bin`
   * Permanently add to `PATH` by adding to `~/.zshrc`

      ```bash
      export PATH="$PATH:/Users/matt/code/lib/flutter/bin"
      ```

   * Verify with

      ```bash
      source ~/.zshrc
      which flutter
      ```

   * For iOS
     * Installing cocoapods via given instructions gave an error. Using Homebrew worked:

      ```bash
      brew install cocoapods
      ```

   * TODO: After getting an Apple Developer account: [Deploy to physical iOS devices](https://docs.flutter.dev/get-started/install/macos#deploy-to-physical-ios-devices)
   * For Android
   * It says "An x86 or x86_64 image is recommended." but this didn't allow selecting `Emulated Performance, select Hardware - GLES 2.0`, so I used an ARM image instead, to get hardware emulation.
   * To resolve `cmdline-tools component is missing` I needed to open Android Studio, go to Settings > Android SDK, and install `Android SDK Command-line Tools (latest)`

2. [Set up VS Code](https://docs.flutter.dev/get-started/editor)

* Note: When running command `Flutter: Run Flutter Doctor` I am seeing this in the Output tab, however those same warnings don't appear when running `flutter doctor -v` directly in a terminal window. I tried adding the same path to `.bashrc` as `.zshrc` but that didn't help.

  ```bash
  ! The flutter binary is not on your path. Consider adding /Users/matt/code/lib/flutter/bin to your path.
  ! The dart binary is not on your path. Consider adding /Users/matt/code/lib/flutter/bin to your path.
  ```

## Running locally from VS Code

1. Select a device from the Status Bar, or command `Flutter: Select Device`
   * For iOS, you may need to manually open the Simulator app first.

2. Open `main.dart`.

3. Select `Start Debugging` from the top right of the editor
