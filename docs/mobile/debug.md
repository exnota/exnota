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
2. `adb -s <device id> reverse tcp:8080 tcp:8080` to forward the port ID

To use a local server over Wifi I think it's necessary to use your computer's network IP or ngrok. The app doesn't have a way to provide this yet.
