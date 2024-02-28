import 'dart:async';
import 'dart:math';
import 'package:clock/clock.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:http/http.dart' as http;

class HealthCheckRetry {
  final _log = Logger(context: 'HealthCheckRetry');

  /// Http client to use for requests to the healthcheck endpoint.
  ///
  /// Passed in to allow for mocking in tests.
  final http.Client client;
  final Uri uri;

  /// Maximum delay in seconds between retries
  final int? maxDelay;

  /// Maximum duration in seconds to keep retrying before giving up
  final int? maxDuration;

  /// Will be called on successful healthcheck
  final Function onSuccess;

  /// Will be called when maxDuration is reached
  final Function? onExpire;

  bool _running = false;
  DateTime? _started;
  Timer? _timer;
  int _prevDelay = 0;

  HealthCheckRetry(
      {required this.client,
      required this.uri,
      this.maxDelay,
      this.maxDuration,
      required this.onSuccess,
      this.onExpire});

  void start() {
    _log.debug('Starting');
    if (_running) {
      _log.warn('Already running');
      return;
    }
    _running = true;
    _started = clock.now();
    _prevDelay = 0;

    _ping();
  }

  void stop() {
    _log.debug('Stopping');
    if (!_running) {
      _log.debug('Not running');
      return;
    }
    _running = false;
    _timer?.cancel();
  }

  Future<void> _ping() async {
    // Ping endpoint
    try {
      _log.debug('Pinging');
      var response = await client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _log.debug('Success');
        onSuccess();
        stop();
        return;
      } else {
        _log.debug('Request failed with status: ${response.statusCode}.');
      }
    } catch (e) {
      _log.debug('Request failed with error: $e');
    }

    if (!_running) {
      _log.debug('Cancelled during request');
      return;
    }

    // Calculate delay
    // Start with 1 second; Double on each iteration.
    _prevDelay = _prevDelay == 0 ? 1 : _prevDelay * 2;

    // Cap delay
    final thisMaxDelay = maxDelay;
    if (thisMaxDelay != null) {
      _prevDelay = min(_prevDelay, thisMaxDelay);
    }

    // Abort if max duration is reached
    final secondsElapsed = clock.now().difference(_started!).inSeconds;
    final thisMaxDuration = maxDuration;
    if (thisMaxDuration != null &&
        secondsElapsed + _prevDelay > thisMaxDuration) {
      _log.debug('Max duration has or will be reached');
      final thisOnExpire = onExpire;
      if (thisOnExpire != null) {
        _log.debug('Calling onExpire');
        thisOnExpire();
      } else {
        _log.warn('No onExpire provided');
      }
      return;
    }

    _log.debug('Scheduling next ping in $_prevDelay seconds');
    _timer = Timer(Duration(seconds: _prevDelay), _ping);
  }
}
