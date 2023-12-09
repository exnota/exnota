import 'package:exnota/src/lib/entity_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncCommand<T> {
  final EntityId id;
  final String entityId;
  final SyncCommandStatus status;

  SyncCommand({required this.id, required this.entityId, required this.status});

  Future<SyncCommandError?> request(Ref ref);
}

enum SyncCommandStatus { waiting, running, complete, error }

@immutable
class SyncCommandError {
  final String message;

  const SyncCommandError(this.message);

  @override
  String toString() {
    return 'SyncCommandError{message: $message}';
  }
}

abstract class NoteSyncCommand extends SyncCommand<NoteSyncCommand> {
  NoteSyncCommand(
      {required EntityId id,
      required String entityId,
      required SyncCommandStatus status})
      : super(id: id, entityId: entityId, status: status);

  String? get captureId;
}
