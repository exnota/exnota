import 'package:exnota/src/lib/data/sync/sync_command.dart';

class CreateAudioNoteSyncCommand extends SyncCommand<String> {
  final String str;

  CreateAudioNoteSyncCommand(
      {required int id, required String entityId, required this.str})
      : super(id: id, entityId: entityId);

  @override
  Future<String> request() {
    return Future.delayed(const Duration(seconds: 2), () => "$entityId-$str");
  }

  @override
  Map<String, dynamic> internalDataToJson() {
    return {'str': str};
  }

  factory CreateAudioNoteSyncCommand.fromJson(
      {required int id,
      required String entityId,
      required Map<String, dynamic> json,
      required SyncCommandStatus status}) {
    return CreateAudioNoteSyncCommand(
        id: id, entityId: entityId, str: json['str'] as String);
  }
}
