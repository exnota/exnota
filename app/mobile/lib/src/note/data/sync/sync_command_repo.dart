import 'dart:convert';

import 'package:exnota/database.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/note/data/sync/sync_command_table.dart';

class SyncCommandRepo {
  final AppDatabase db;

  SyncCommandRepo(this.db);

  Future<List<SyncCommand>> fetchAll() async {
    final all = await db.select(db.syncCommandTable).get();
    return all.map((e) {
      final data = jsonDecode(e.data);
      switch (e.type) {
        case SyncCommandType.createAudioNote:
          return CreateAudioNoteSyncCommand.fromJson(
              entityId: e.entityId, json: data as Map<String, dynamic>);
        default:
          throw Exception('Unknown command type');
      }
    }).toList();
  }

  Stream<List<SyncCommand>> fetchAllStream() {
    return db.select(db.syncCommandTable).map<SyncCommand>((e) {
      final data = jsonDecode(e.data);
      switch (e.type) {
        case SyncCommandType.createAudioNote:
          return CreateAudioNoteSyncCommand.fromJson(
              entityId: e.entityId, json: data as Map<String, dynamic>);
        default:
          throw Exception('Unknown command type');
      }
    }).watch();
  }

  Future<void> create(SyncCommand cmd) async {
    SyncCommandType type;
    switch (cmd.runtimeType) {
      case CreateAudioNoteSyncCommand:
        type = SyncCommandType.createAudioNote;
        break;
      default:
        throw Exception('Unknown command type');
    }
    final data = cmd.toJson();
    SyncCommandTableCompanion toInsert = SyncCommandTableCompanion.insert(
        type: type, entityId: cmd.entityId, data: jsonEncode(data));
    await db.into(db.syncCommandTable).insert(toInsert);
  }
}
