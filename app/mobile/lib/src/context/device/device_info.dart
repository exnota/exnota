import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_info.g.dart';
part 'device_info.freezed.dart';

@Riverpod(keepAlive: true)
DeviceInfo deviceInfoService(DeviceInfoServiceRef ref) {
  // This will be added using an override in main.dart as per https://github.com/bizz84/flutter-tips-and-tricks/blob/main/tips/0056-async-init-provider-overrides/index.md
  throw UnimplementedError();
}

@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required bool isPhysicalDevice,
    required bool isAndroid,
    required bool isIos,
  }) = _DeviceInfo;
}

Future<DeviceInfo> initDeviceInfoService() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return DeviceInfo(
        isPhysicalDevice: androidInfo.isPhysicalDevice,
        isAndroid: true,
        isIos: false,
      );
    case TargetPlatform.iOS:
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      return DeviceInfo(
        isPhysicalDevice: iosInfo.isPhysicalDevice,
        isAndroid: false,
        isIos: true,
      );
    default:
      throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
  }
}
