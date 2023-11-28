import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncCommandStatus { waiting, running, complete }

abstract class SyncCommand<T> {
  final int id;
  final String entityId;
  final SyncCommandStatus status;

  SyncCommand(
      {required this.id,
      required this.entityId,
      this.status = SyncCommandStatus.waiting});

  Future<void> request(Ref ref);

  Map<String, dynamic> internalDataToJson();

  Map<String, dynamic> dataToJson() {
    return internalDataToJson();
  }
}
