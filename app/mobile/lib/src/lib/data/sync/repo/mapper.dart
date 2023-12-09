import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_table.dart';
import 'package:exnota/src/lib/entity_id.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mapper.g.dart';

class SyncCommandRepoMapper {
  static SyncCommandTableCompanion toDataInsert(SyncCommand command) {
    final logger = Logger(context: 'SyncCommandRepoMapper.toDataInsert');
    switch (command) {
      case CreateAudioNoteSyncCommand():
        final data = CreateAudioNoteDataRepo(capture: (
          id: command.capture.id,
          filePath: command.capture.filePath
        ));
        final id = command.id;
        if (id case EntityWithId()) {
          logger.warn("Command passed with ID. This will be ignored",
              nonPrivateData: {
                'id': id.id,
                'entityId': command.entityId,
                'syncCommand': command.runtimeType,
              });
        }
        return SyncCommandTableCompanion.insert(
            type: SyncCommandRepoType.createAudioNote,
            entityId: command.entityId,
            data: json.encode(data.toJson()),
            status: statusToData(command.status));
      default:
        throw Exception("Unknown command type: ${command.runtimeType}");
    }
  }

  static SyncCommand fromData(SyncCommandTableData commandData) {
    final data =
        CreateAudioNoteDataRepo.fromJson(json.decode(commandData.data));
    switch (commandData.type) {
      case SyncCommandRepoType.createAudioNote:
        return CreateAudioNoteSyncCommand.fromDb(
            id: commandData.id,
            entityId: commandData.entityId,
            captureId: data.capture.id,
            filePath: data.capture.filePath,
            status: statusFromData(commandData.status));
      default:
        throw Exception("Unknown command type: ${commandData.type}");
    }
  }

  static SyncCommandRepoStatus statusToData(SyncCommandStatus status) {
    switch (status) {
      case SyncCommandStatus.waiting:
        return SyncCommandRepoStatus.waiting;
      case SyncCommandStatus.running:
        return SyncCommandRepoStatus.running;
      case SyncCommandStatus.complete:
        return SyncCommandRepoStatus.complete;
      case SyncCommandStatus.error:
        return SyncCommandRepoStatus.error;
    }
  }

  static SyncCommandStatus statusFromData(SyncCommandRepoStatus status) {
    switch (status) {
      case SyncCommandRepoStatus.waiting:
        return SyncCommandStatus.waiting;
      case SyncCommandRepoStatus.running:
        return SyncCommandStatus.running;
      case SyncCommandRepoStatus.complete:
        return SyncCommandStatus.complete;
      case SyncCommandRepoStatus.error:
        return SyncCommandStatus.error;
    }
  }
}

@JsonSerializable()
class CreateAudioNoteDataRepo {
  @JsonKey(name: 'capture')
  final ({String id, String filePath}) capture;

  CreateAudioNoteDataRepo({required this.capture});

  factory CreateAudioNoteDataRepo.fromJson(Map<String, dynamic> json) =>
      _$CreateAudioNoteDataRepoFromJson(json);

  Map<String, dynamic> toJson() => _$CreateAudioNoteDataRepoToJson(this);
}
