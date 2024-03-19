import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_audio_note_sync_command.freezed.dart';
part 'create_audio_note_sync_command.g.dart';

@freezed
class CreateAudioBlockData with _$CreateAudioBlockData {
  const factory CreateAudioBlockData({
    required String userId,
    required DateTime userCreated,
    required String localFileId,
  }) = _CreateAudioBlockData;

  factory CreateAudioBlockData.fromJson(Map<String, dynamic> json) =>
      _$CreateAudioBlockDataFromJson(json);
}

class CreateAudioBlockSyncCommand extends SyncCommand<Block> {
  static final _log = Logger(context: 'CreateAudioBlockSyncCommand');

  final CreateAudioBlockData data;

  CreateAudioBlockSyncCommand._(
      {required String id,
      required String entityId,
      required String rootEntityId,
      required String userId,
      required SyncCommandStatus status,
      required String? result,
      required DateTime createdAt,
      required DateTime? startedAt,
      required DateTime updatedAt,
      required this.data})
      : super(
            id: id,
            entityId: entityId,
            rootEntityId: rootEntityId,
            userId: userId,
            status: status,
            result: result,
            createdAt: createdAt,
            startedAt: startedAt,
            updatedAt: updatedAt);

  @override
  Future<Block> localUpdate({required Block? current}) {
    _log.debug('localUpdate: Start');
    // Not expected to have a current value
    if (current != null) {
      throw Exception('Unexpected current value');
    }

    final block = Block.createAudio(
      id: entityId,
      userId: userId,
      userCreated: data.userCreated,
    );
    _log.debug('localUpdate: End');
    return Future.value(block);
  }

  @override
  Future<Block> syncUpdate({required ProviderContainer container}) async {
    _log.debug('syncUpdate: Start');
    // TODO:
    await Future.delayed(const Duration(seconds: 5));

    _log.debug('syncUpdate: End');
    // TODO: Update this to return the block from the server
    return Future.value(Block.createAudio(
      id: entityId,
      userId: userId,
      userCreated: data.userCreated,
    ));
  }

  // Factories
  factory CreateAudioBlockSyncCommand.createWaiting(
      {required String userId, required CreateAudioBlockData data}) {
    final now = DateTime.now();
    final blockId = generateId();
    return CreateAudioBlockSyncCommand._(
      id: generateId(),
      entityId: blockId,
      rootEntityId: blockId,
      userId: userId,
      status: SyncCommandStatus.waiting,
      result: null,
      createdAt: now,
      startedAt: null,
      updatedAt: now,
      data: data,
    );
  }

  factory CreateAudioBlockSyncCommand.fromDb(
      {required String id,
      required String entityId,
      required String rootEntityId,
      required String userId,
      required CreateAudioBlockData data,
      required SyncCommandStatus status,
      required String? result,
      required DateTime createdAt,
      required DateTime? startedAt,
      required DateTime updatedAt}) {
    return CreateAudioBlockSyncCommand._(
      id: id,
      entityId: entityId,
      rootEntityId: rootEntityId,
      userId: userId,
      status: status,
      result: result,
      createdAt: createdAt,
      startedAt: startedAt,
      updatedAt: updatedAt,
      data: data,
    );
  }
}
