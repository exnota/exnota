# Home Screen Widget

## iOS

### Error: `Cycle inside Runner`

Solution: <https://github.com/flutter/flutter/issues/134256#issuecomment-1712053622>

1. In Xcode
2. Project navigator > Select Runner
3. Under Targets, select Runner
4. Select 'Build phases' tab
5. Drag Embed Foundation Extensions to be just under Copy Bundle Resources.

### Running error: SendProcessControlEvent:toPid: encountered an error: Error Domain=

- Target > WidgetExtension > General tab: Ensure 'Minimum deployment' matches the device.
  - I got this unhelpful error when I tried running with minimum deployment iOS 17 on a device with 15.5.

```bash
SendProcessControlEvent:toPid: encountered an error: Error Domain=com.apple.dt.deviceprocesscontrolservice Code=8 "Failed to show Widget 'com.exnota.mobile.RecordWidget' error: Error Domain=FBSOpenApplicationServiceErrorDomain Code=1 "The request to open "com.apple.springboard" failed."
```

### Debugging

From Google's tutorial:

> Note: [Xcode 14.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-14_1-release-notes#Known-Issues) mention a bug with debugging widgets. You can find [some helpful tips for debugging](https://stackoverflow.com/questions/64922585/xcode-ios-14-widgetkit-not-always-attached-to-debugger) in StackOverflow.
