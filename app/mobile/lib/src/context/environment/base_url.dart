import 'package:exnota/src/context/device/device_info.dart';
import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'base_url.g.dart';

@riverpod
class BaseUrl extends _$BaseUrl {
  final Logger _log = Logger(context: 'UriService');

  @override
  Uri build() {
    _log.info('Building');
    final environment = ref.watch(environmentServiceProvider);
    final deviceInfo = ref.watch(deviceInfoServiceProvider);

    switch (environment) {
      case Environment.local:
        _log.info('Detected local environment');
        if (deviceInfo.isAndroid) {
          _log.info('Detected Android device');
          if (deviceInfo.isPhysicalDevice) {
            _log.info('Detected physical device');
            // You'll need to forward port 8080 to your computer. See
            // docs/mobile/debug.md
            return Uri.http('127.0.0.1:8080');
          } else {
            _log.info('Detected emulator');
            // Android simulator needs 10.0.2.2 to access localhost
            return Uri.http('10.0.2.2:8080');
          }
        } else {
          _log.info('Detected iOS device');
          return Uri.http('localhost:8080');
        }
      case Environment.prod:
        _log.info('Detected prod environment');
        return Uri.https('exnota.matt.to');
    }
  }
}
