import 'dart:async';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:http/http.dart' as http;

class HealthCheck {
  /// Pings the given uri with a timeout and returns `true` if the request
  /// succeeds.
  ///
  /// Catches exceptions.
  static Future<bool> ping(
      {required Uri uri,
      required http.Client client,
      required String label}) async {
    final log = Logger(context: 'HealthCheck.$label');
    log.debug('Pinging $uri');
    try {
      // After implementing this I realised there's also `pb.health.check();` in
      // the official SDK. But I'm not sure it has a timeout and I can't see
      // much to gain in refactoring this to use it.
      var response = await client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        log.debug('Success');
        return true;
      } else {
        log.debug('Request failed with status: ${response.statusCode}.');
      }
    } on TimeoutException {
      log.debug('Request timed out');
    } on Exception catch (e) {
      log.debug('Request failed with exception ${e.runtimeType}');
    } catch (e) {
      log.debug('Request failed with unknown exception: $e');
    }
    return false;
  }
}
