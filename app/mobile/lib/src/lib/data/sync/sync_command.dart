enum SyncCommandStatus { waiting, running, complete }

abstract class SyncCommand<T> {
  final int id;
  final String entityId;
  final SyncCommandStatus status;

  SyncCommand(
      {required this.id,
      required this.entityId,
      this.status = SyncCommandStatus.waiting});

  Future<T> request();

  Map<String, dynamic> internalDataToJson();

  Map<String, dynamic> dataToJson() {
    return internalDataToJson();
  }
}
