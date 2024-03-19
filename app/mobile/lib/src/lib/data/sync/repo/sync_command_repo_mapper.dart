import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';

class SyncCommandRepoMapper {
  static final _log = Logger(context: 'SyncCommandRepoMapper');

  static SyncCommandTableData toRepo(SyncCommand command) {
    _log.debug('toData: $command');
    switch (command) {
      case CreateAudioBlockSyncCommand():
        final data = jsonEncode(command.data.toJson());
        return SyncCommandTableData(
            id: command.id,
            type: 'createAudioBlock',
            entityId: command.entityId,
            rootEntityId: command.rootEntityId,
            userId: command.userId,
            status: statusToData(command.status),
            result: command.result,
            data: data,
            createdAt: command.createdAt,
            startedAt: command.startedAt,
            updatedAt: command.updatedAt);
      default:
        throw Exception('Unknown command type: ${command.runtimeType}');
    }
  }

  static SyncCommand fromData(SyncCommandTableData commandData) {
    _log.debug('fromData: $commandData');
    switch (commandData.type) {
      case 'createAudioBlock':
        final data =
            CreateAudioBlockData.fromJson(jsonDecode(commandData.data));
        return CreateAudioBlockSyncCommand.fromDb(
            id: commandData.id,
            entityId: commandData.entityId,
            rootEntityId: commandData.rootEntityId,
            userId: commandData.userId,
            status: statusFromData(commandData.status),
            result: commandData.result,
            createdAt: commandData.createdAt,
            startedAt: commandData.startedAt,
            updatedAt: commandData.updatedAt,
            data: data);
      default:
        throw Exception('Unknown command type: ${commandData.type}');
    }
  }

  static String statusToData(SyncCommandStatus status) {
    switch (status) {
      case SyncCommandStatus.waiting:
        return 'waiting';
      case SyncCommandStatus.running:
        return 'running';
      case SyncCommandStatus.complete:
        return 'complete';
      case SyncCommandStatus.error:
        return 'error';
    }
  }

  static SyncCommandStatus statusFromData(String status) {
    switch (status) {
      case 'waiting':
        return SyncCommandStatus.waiting;
      case 'running':
        return SyncCommandStatus.running;
      case 'complete':
        return SyncCommandStatus.complete;
      case 'error':
        return SyncCommandStatus.error;
      default:
        throw Exception('Unknown status: $status');
    }
  }
}
