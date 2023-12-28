import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

@riverpod
Clock clock(ClockRef ref) {
  return Clock();
}

class Clock {
  DateTime now() {
    return DateTime.now();
  }
}
