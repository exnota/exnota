# Exnota mobile flutter app  <!-- omit from toc -->

- [Development principles](#development-principles)
  - [Robustness: Liberally accept external data](#robustness-liberally-accept-external-data)
  - [Robustness: Be conservative with app-initiated data mutations](#robustness-be-conservative-with-app-initiated-data-mutations)
- [Design decisions](#design-decisions)
- [Installation](#installation)

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

- Send specific mutations to backend, rather than full objects.
  - So old app versions missing data don't override backend data.
- Use strict, custom factories when making user-initiated changes to domain objects.
  - E.g. creation: `factory DomainObject.create(...)`
  - E.g. updates: `DomainObject copyWithNewStatus(Status status)`
- Don't allow updating/exporting of unknown note/capture types.

## Design decisions

- For optional domain object fields, use `required Optional<T>` on constructors
so an error is thrown if `.fromDb` and other methods are not updated.

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
