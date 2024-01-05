# Debug

## Physical device

### Android

1. Connect via USB
2. In VS Code: `Flutter: Select Device` and choose physical device
3. Run as you would using a simulator

If there's already an app version on, it may error trying to uninstall. Retry - it should work the second time.

#### Local environment

To use a local server when connected via USB:
1. `adb devices` to find the device ID
2. `adb -s <device id> reverse tcp:3000 tcp:3000` to forward the port ID

To use a local server over Wifi I think it's necessary to use your computer's network IP or ngrok. The app doesn't have a way to provide this yet.

### iOS (some duplication with ./install.md)

Apparently need to get it working in Xcode first, then should be able to debug in VS Code ([link](https://stackoverflow.com/questions/54444538/how-do-i-run-test-my-flutter-app-on-a-real-device)).

1. Open Xcode
2. Ensure each project is assigned to a team: <https://help.apple.com/xcode/mac/current/#/dev23aab79b4>
3. Select device: `Runner > <device name>`
4. Press Run (play button)

To run from VS Code, use the same steps as for Android. Breakpoints should work.

#### Viewing logs in Xcode

1. In Xcode, go to Report Navigator (left sidebar, furthest icon on right).
2. Select 'Console' under the currently running build (should have a spinner)

Bottom right panel seems to have the live log feed.

#### Troubleshooting

If you get 'Untrusted Developer'

1. Settings > General > Device Management, and select to trust
2. Then try building in Xcode again.

From VS Code, if you get: `“iproxy” cannot be opened because the developer cannot be verified.`

1. Try `rm -rf /Users/matt/code/lib/flutter/bin/cache/artifacts` (replace user name)
