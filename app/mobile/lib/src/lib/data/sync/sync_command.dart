import 'package:exnota/src/lib/entity_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncCommand<T> {
  final EntityId id;
  final String entityId;
  final String rootEntityId;
  final SyncCommandStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SyncCommand(
      {required this.id,
      required this.entityId,
      required this.rootEntityId,
      required this.status,
      required this.createdAt,
      required this.updatedAt});

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
