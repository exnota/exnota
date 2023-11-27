abstract class SyncCommand<T> {
  final String entityId;

  SyncCommand(this.entityId);

  Future<T> request();

  // TODO: Rename below methods to reference 'data' and remove
  // any that aren't used.
  Map<String, dynamic> internalToJson();

  Map<String, dynamic> toJson() {
    return internalToJson();
  }

  T internalFromJson(Map<String, dynamic> json);

  T fromJson(Map<String, dynamic> json) {
    return internalFromJson(json);
  }
}
