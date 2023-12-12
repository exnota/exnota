# Release

## Android: Release to Play store (WIP)

1. Download keystore `upload-keystore.jks` from secure location.

2. Place in `/app/mobile/android/app`. Don't change the filename.
   - .gitignore should prevent this from being committed.

3. Duplicate `android/key.properties.template`, renaming to `key.properties`
   - .gitignore should prevent this from being committed.

4. Update both `storePassword` and `keyPassword` in the file to the keystore
password. Both are the same password.

------

1. Bump version in `pubspec.yaml`.

2. Run `flutter build appbundle`
