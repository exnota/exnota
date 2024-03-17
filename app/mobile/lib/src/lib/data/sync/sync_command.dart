import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncCommand<T> {
  final String id;
  final String entityId;
  final String rootEntityId;
  final String userId;
  final SyncCommandStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SyncCommand(
      {required this.id,
      required this.entityId,
      required this.rootEntityId,
      required this.userId,
      required this.status,
      required this.createdAt,
      required this.updatedAt});

  Future<T> syncUpdate({required ProviderContainer container});

  Future<T> localUpdate({required T? current});
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
