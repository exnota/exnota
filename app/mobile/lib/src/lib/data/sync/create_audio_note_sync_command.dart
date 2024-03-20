import 'dart:async';

import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_fetcher.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;

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
      userId: data.userId,
      userCreated: data.userCreated,
    );
    _log.debug('localUpdate: End');
    return Future.value(block);
  }

  @override
  Future<Block> syncUpdate({required ProviderContainer container}) async {
    _log.debug('syncUpdate: Start');

    final submitComletor = Completer<Block>();
    final created = await localUpdate(current: null);
    final recording = await container
        .read(getLocalFileByIdOrThrowProvider(data.localFileId).future);

    final request = CreateAudioRequest(created: created, recording: recording);
    await container.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (result) {
            _log.debug('syncUpdate: Success');
            submitComletor.complete(result);
          },
          onError: (err) {
            _log.debug('syncUpdate: Failed with error: $err');
            submitComletor.completeError(err);
          },
        );

    _log.debug('syncUpdate: End');
    return submitComletor.future;
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

class CreateAudioRequest extends HandledRequest<Block> {
  static final Logger _log = Logger(context: 'CreateAudioRequest');

  final Block created;
  final LocalFile recording;

  CreateAudioRequest({required this.created, required this.recording});

  @override
  Duration get timeout => const Duration(minutes: 3);

  @override
  Future<Block> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Request: Start');
    _log.debug('Request: Creating multipart file');
    final multipartFile = await http.MultipartFile.fromPath(
      'file', // the name of the file field
      recording.path,
    );

    _log.debug('Request: Sending request to server');
    final responseRecord = await pb.collection('block').create(
      body: created.toCreateRequestBody(),
      files: [multipartFile],
    );

    _log.debug('Request: Parsing response');
    final response = Block.fromRecord(responseRecord);

    _log.debug('Request: End');
    return response;
  }
}
