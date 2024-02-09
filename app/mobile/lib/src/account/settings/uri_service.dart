import 'package:exnota/src/account/settings/environment_service.dart'
    as env_legacy;
import 'package:exnota/src/account/settings/settings_service.dart';
import 'package:exnota/src/lib/env/device_info.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'uri_service.g.dart';

@riverpod
class UriService extends _$UriService {
  final Logger _log = Logger(context: 'UriService');

  @override
  Uri build() {
    _log.info('build: Building uri service');
    final settings = ref.watch(settingsServiceProvider).requireValue;
    final deviceInfo = ref.watch(deviceInfoProvider);
    switch (settings.environment) {
      case Environment.local:
        _log.info('build: Building local uri');
        if (deviceInfo.isAndroid) {
          if (deviceInfo.isPhysicalDevice) {
            _log.info('build: Building local uri for physical device');
            // You'll need to forward port 8080 to your computer. See
            // docs/mobile/debug.md
            return Uri.http('127.0.0.1:8080');
          } else {
            _log.info('build: Building local uri for emulator');
            // Android simulator needs 10.0.2.2 to access localhost
            return Uri.http("10.0.2.2:8080");
          }
        }
        _log.info('build: Building local uri for iOS');
        return Uri.http('localhost:8080');
      case Environment.prod:
        _log.info('build: Building prod uri');
        return Uri.https('exnota.matt.to');
    }
  }
}

@riverpod
class UriServiceLegacy extends _$UriServiceLegacy {
  @override
  Uri build({String path = '', bool? noApi = false}) {
    final environment = ref.read(env_legacy.environmentServiceProvider);
    final deviceInfo = ref.read(deviceInfoProvider);
    switch (environment) {
      case env_legacy.Environment.local:
        if (deviceInfo.isAndroid) {
          if (deviceInfo.isPhysicalDevice) {
            // You'll need to forward port 3000 to your computer. See
            // docs/mobile/debug.md
            return Uri.http('localhost:3000', path);
          } else {
            // Android simulator needs 10.0.2.2 to access localhost
            return Uri.http("10.0.2.2:3000", path);
          }
        }
        return Uri.http('localhost:3000', path);
      case env_legacy.Environment.prod:
        if (path.isEmpty) {
          return Uri.https('exnota.com');
        }
        if (noApi == true) {
          return Uri.https('exnota.com', path);
        }
        return Uri.https('exnota.com', 'api/$path');
    }
  }
}
