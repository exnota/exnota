import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncCommandStatus { waiting, running, complete, error }

abstract class SyncCommand<T> {
  final int id;
  final String entityId;
  final SyncCommandStatus status;

  SyncCommand({required this.id, required this.entityId, required this.status});

  Future<SyncCommandError?> request(Ref ref);
}

@immutable
class SyncCommandError {
  final String message;

  const SyncCommandError(this.message);

  @override
  String toString() {
    return 'SyncCommandError{message: $message}';
  }
}
