import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/lib/env/device_info.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'uri_service.g.dart';

@riverpod
class UriService extends _$UriService {
  @override
  Uri build({String path = '', bool? noApi = false}) {
    final environment = ref.read(environmentServiceProvider);
    final deviceInfo = ref.read(deviceInfoProvider);
    switch (environment) {
      case Environment.local:
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
      case Environment.prod:
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
