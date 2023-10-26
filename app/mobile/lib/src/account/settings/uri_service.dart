import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'uri_service.g.dart';

@riverpod
class UriService extends _$UriService {
  @override
  Uri build({String path = '', bool? noApi = false}) {
    final environment = ref.read(environmentServiceProvider);
    switch (environment) {
      case Environment.local:
        if (defaultTargetPlatform == TargetPlatform.android) {
          // Android simulator needs 10.0.2.2 to access localhost
          return Uri.http("10.0.2.2:3000", path);
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
