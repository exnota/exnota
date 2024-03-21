import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clock/clock.dart' as clk;

part 'clock.g.dart';

@riverpod
Clock clock(ClockRef ref) {
  return Clock();
}

/// DateTime wrapper to allow mocking in tests and maintaining timezone
/// consistency.
///
/// You can use [async.elapse] from the [fake_async] package when testing to
/// advance the time.
class Clock {
  DateTime now() {
    // DateTimes must be set to UTC because toIso8601String will exclude
    // the timezone for anything non-UTC. Then PocketBase converts to UTC.
    //
    // We should do this everywhere, even for dates that are local only,
    // for consistency.
    //
    // An alternative would be to add the timezone, but using toUtc() seems
    // simpler, and should be fine to not persist the timezone.
    return clk.clock.now().toUtc();
  }
}
