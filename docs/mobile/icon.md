# Icon

How to update app icons.

## Android: Using Image Asset Studio

1. Prepare image with a LOT of space around sides
2. Open Android Studio
3. In the Project window, select the Android view.
4. Right-click the res folder and select New > Image Asset.
5. Follow the Image Asset Studio wizard to generate files.
6. If you used a new filename:
   1. Update it in `android/app/src/main/AndroidManifest.xml` in `<application android:icon="@mipmap/<filename>`
   2. Delete old files
7. Add to `/asset/icon/` for reference.

## iOS

As of ~2022 it's possible to use a single image and Xcode will generate variations at build time (I guess). Keyword: "single size".

1. Prepare a 1024x1024 image (without excess space, different to Android)
2. In the Project navigator, go to `Runner > Runner > Assets`
3. Click the Add button (+) at the bottom of the outline view.
4. Select `iOS > iOS App Icon`

Not sure about this, but the name 'AppIcon' may be required, which also means you can only have one at a time.

[Reference](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
