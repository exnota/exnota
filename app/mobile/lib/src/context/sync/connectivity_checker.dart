import 'dart:async';
import 'dart:math';
import 'package:clock/clock.dart';
import 'package:exnota/src/context/sync/health_check.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'connectivity_checker.freezed.dart';

enum ConnectivityCheckerStatus {
  online,
  offline,
}

@freezed
class CheckerStrategy with _$CheckerStrategy {
  @Assert('interval >= 0')
  const factory CheckerStrategy.detectOffline({
    /// The interval in seconds at which to check for connectivity.
    required int interval,

    /// Called when the connection is detected to be offline.
    required Function onOffline,
  }) = DetectOfflineStrategy;

  // Not sure if this will work when maxInterval is null
  @Assert('maxInterval == null || maxInterval >= 0')
  const factory CheckerStrategy.unlimitedRetry({
    /// The maximum interval in seconds between retries.
    int? maxInterval,

    /// Called when the connection is detected to be online.
    required Function onOnline,
  }) = UnlimitedRetryStrategy;

  @Assert('maxDuration >= 0')
  const factory CheckerStrategy.durationRetry({
    /// The maximum duration in seconds to attempt retries before giving up and
    /// calling onExpire.
    ///
    /// The duration is measured from the start of the first attempt until the
    /// projected start time (current time + next interval) of the next
    /// attempt.
    required int maxDuration,

    /// Called when the connection is detected to be online.
    required Function onOnline,

    /// Called when the max duration has been reached with no success.
    required Function onExpire,
  }) = DurationRetryStrategy;

  @Assert('maxAttempts >= 1')
  const factory CheckerStrategy.fixedRetry({
    /// The number of attempts to make before calling onExpire.
    required int maxAttempts,

    /// Called when the connection is detected to be online.
    required Function onOnline,

    /// Called when the fixed number of attempts have been made with no success.
    required Function onExpire,
  }) = FixedRetryStrategy;
}

class ConnectivityChecker {
  late final Logger _log;

  /// Http client to use for requests to the healthcheck endpoint.
  ///
  /// Passed in to allow for mocking in tests.
  final http.Client client;
  final Uri uri;
  final CheckerStrategy strategy;

  /// An identifier for logging.
  final String label;

  Completer<ConnectivityCheckerStatus?>? _completer;
  ConnectivityCheckerStatus? _lastStatus;
  DateTime? _started;

  int _attempt = 0;
  int _backoffInterval = 0;
  Timer? _timer;

  ConnectivityChecker({
    required this.strategy,
    required this.uri,
    required this.client,
    required this.label,
  }) {
    _log = Logger(context: 'ConnectivityChecker.$label');
  }

  /// Returns a future of the status of the last connection attempt.
  ///
  /// `null` if the first connection attempt has not yet completed.
  ///
  /// This is an alternative to using the callbacks in the strategy.
  ///
  /// When or whether the future completes will depends on the strategy. E.g. a
  /// detect offline strategy may never complete if the connection is never
  /// detected to be offline.
  Future<ConnectivityCheckerStatus?> start() async {
    _log.debug('Starting');
    if (_completer != null) {
      _log.warn('Already started');
      return _completer!.future;
    }
    // The type must be optional. It won't show a compile time error but will
    // throw a runtime error when passed `null`.
    //
    // I.e. use this `Completer<ConnectivityCheckerStatus?>();` NOT
    // `Completer<ConnectivityCheckerStatus>();`
    _completer = Completer<ConnectivityCheckerStatus?>();
    _started = clock.now();

    unawaited(_ping());
    return _completer!.future;
  }

  void stop() {
    if (_completer == null) {
      _log.debug('Stop: Not started');
      return;
    }
    if (_completer!.isCompleted) {
      _log.debug('Stop: Already stopped');
      return;
    }

    _log.debug('Stop: Stopping');
    _timer?.cancel();
    _completer!.complete(_lastStatus);
  }

  Future<void> _ping() async {
    // Ping endpoint
    final online =
        await HealthCheck.ping(uri: uri, client: client, label: label);
    _lastStatus = online
        ? ConnectivityCheckerStatus.online
        : ConnectivityCheckerStatus.offline;

    if (_completer!.isCompleted) {
      _log.debug('Stopped during request');
      return;
    }

    switch (strategy) {
      case DetectOfflineStrategy():
        final offlineStrategy = (strategy as DetectOfflineStrategy);
        if (!online) {
          _log.debug('Calling onOffline');
          offlineStrategy.onOffline();
          _completer?.complete(ConnectivityCheckerStatus.offline);
          return;
        }

        _log.debug(
            'Scheduling next ping in ${offlineStrategy.interval} seconds');
        _timer = Timer(Duration(seconds: offlineStrategy.interval), _ping);
        break;

      case UnlimitedRetryStrategy():
        final retryStrategy = (strategy as UnlimitedRetryStrategy);
        if (online) {
          _log.debug('Calling onOnline');
          retryStrategy.onOnline();
          _completer?.complete(ConnectivityCheckerStatus.online);
          return;
        }

        // Start with 1 second; Double on each iteration.
        var nextInterval = _backoffInterval == 0 ? 1 : _backoffInterval * 2;

        // Cap interval
        final max = retryStrategy.maxInterval;
        if (max != null) {
          nextInterval = min(nextInterval, max);
        }

        _log.debug('Scheduling next ping in $nextInterval seconds');
        _timer = Timer(Duration(seconds: nextInterval), _ping);
        _backoffInterval = nextInterval;
        break;

      case DurationRetryStrategy():
        final retryStrategy = (strategy as DurationRetryStrategy);
        if (online) {
          _log.debug('Calling onOnline');
          retryStrategy.onOnline();
          _completer?.complete(ConnectivityCheckerStatus.online);
          return;
        }

        // Start with 1 second; Double on each iteration.
        var nextInterval = _backoffInterval == 0 ? 1 : _backoffInterval * 2;

        // Expire if max duration reached
        final secondsElapsed = clock.now().difference(_started!).inSeconds;
        if (secondsElapsed + nextInterval > retryStrategy.maxDuration) {
          _log.debug('Max duration has or will be reached. Calling onExpire');
          retryStrategy.onExpire();
          _completer?.complete(ConnectivityCheckerStatus.offline);
          return;
        }

        _log.debug('Scheduling next ping in $nextInterval seconds');
        _timer = Timer(Duration(seconds: nextInterval), _ping);
        _backoffInterval = nextInterval;
        break;

      case FixedRetryStrategy():
        final retryStrategy = (strategy as FixedRetryStrategy);
        _attempt++;
        if (online) {
          _log.debug('Calling onOnline');
          retryStrategy.onOnline();
          _completer?.complete(ConnectivityCheckerStatus.online);
          return;
        }

        // Expire if max attempts reached
        if (_attempt >= retryStrategy.maxAttempts) {
          _log.debug('Max attempts reached ($_attempt)');
          _log.debug('Calling onExpire');
          retryStrategy.onExpire();
          _completer?.complete(ConnectivityCheckerStatus.offline);
          return;
        }

        // Retry immediately
        unawaited(_ping());
        break;
    }
  }
}
