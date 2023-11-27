import 'package:exnota/src/lib/data/sync/sync_command.dart';

class CreateAudioNoteSyncCommand extends SyncCommand<String> {
  final String str;

  CreateAudioNoteSyncCommand({required String entityId, required this.str})
      : super(entityId);

  @override
  Future<String> request() {
    return Future.delayed(const Duration(seconds: 1), () => str);
  }

  @override
  String internalFromJson(Map<String, dynamic> json) {
    return json['str'] as String;
  }

  @override
  Map<String, dynamic> internalToJson() {
    return {'str': str};
  }

  factory CreateAudioNoteSyncCommand.fromJson(
      {required String entityId, required Map<String, dynamic> json}) {
    return CreateAudioNoteSyncCommand(
        entityId: entityId, str: json['str'] as String);
  }
}
