import 'dart:async';

import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_runner.dart';
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

    final block = _blockFromData();
    _log.debug('localUpdate: End');
    return Future.value(block);
  }

  Block _blockFromData() {
    return Block.createAudio(
      id: entityId,
      userId: data.userId,
      userCreated: data.userCreated,
    );
  }

  @override
  Future<Block> syncUpdate({required ProviderContainer container}) async {
    _log.debug('syncUpdate: Start');

    final submitCompletor = Completer<Block>();
    final created = _blockFromData();
    final recording = await container
        .read(getLocalFileByIdOrThrowProvider(data.localFileId).future);

    final request = CreateAudioRequest(created: created, recording: recording);
    await container.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (createResponse) {
            _log.debug('syncUpdate: Success');
            submitCompletor.complete(createResponse);
          },
          onError: (createErr) {
            _log.debug('syncUpdate: Failed with error: $createErr');
            // Check if was block already created.
            //
            // It's possible that the block was created on the backend but we
            // encountered an error between then and completing the command. So
            // the command is retried but fails because the block already
            // exists on the backend. This could happen, for example, if we
            // time out the future for the command's request but it continues
            // in the background and completes. Currently I don't think there's
            // a way to properly cancel a request using PocketBase, and possibly
            // not with dart either. Instead we just time out the future which
            // stops waiting for a response.
            //
            // We want to be careful when assuming that the block was
            // successfully created because if we're wrong and mark the command
            // complete, the user will think their data has been exported when
            // it hasn't.
            //
            // First: Check for the expected error: `validation_invalid_id`.
            // This can be thrown if the ID is already in use OR it's not a
            // valid ID. So this isn't a sufficient chec by itself.
            //
            // Second: Try fetching the block from the backend and verifying
            // that userCreated matches the local value.
            //
            // If both of those are true, we can assume the block was
            // successfully created and can mark the command as complete.
            if (createErr is ClientException &&
                createErr.response['data']?['id']?['code'] ==
                    'validation_invalid_id') {
              _verifyBlockCreated(
                container: container,
                onSuccess: (verifyResponse) {
                  // Server persists to milliseconds (3 decimals) while DateTime
                  // seems to create new instances with 5 decimals
                  // (microseconds?).
                  if (verifyResponse.userCreated.millisecondsSinceEpoch ==
                      created.userCreated.millisecondsSinceEpoch) {
                    submitCompletor.complete(verifyResponse);
                  } else {
                    submitCompletor.completeError(createErr);
                  }
                },
                onError: (verifyErr) {
                  submitCompletor.completeError(verifyErr);
                },
              );
              return;
            }
            submitCompletor.completeError(createErr);
          },
        );

    _log.debug('syncUpdate: End');
    return submitCompletor.future;
  }

  void _verifyBlockCreated(
      {required ProviderContainer container,
      required Function(Block) onSuccess,
      required Function(Object) onError}) async {
    final request = VerifyCreatedRequest(created: _blockFromData());
    await container.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: onSuccess,
          onError: onError,
        );
  }

  // Factories
  factory CreateAudioBlockSyncCommand.createWaiting(
      {required String userId, required CreateAudioBlockData data}) {
    final now = Clock().now();
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
  Duration get timeout => commandRequestTimeout;

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

class VerifyCreatedRequest extends HandledRequest<Block> {
  static final Logger _log = Logger(context: 'VerifyCreatedRequest');

  final Block created;

  VerifyCreatedRequest({required this.created});

  @override
  Duration get timeout => commandRequestTimeout;

  @override
  Future<Block> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Request: Start');
    _log.debug('Request: Sending request to server');
    final remoteRecord = await pb.collection('block').getOne(created.id);

    _log.debug('Request: Parsing response');
    final remoteBlock = Block.fromRecord(remoteRecord);

    _log.debug('Request: End');
    return remoteBlock;
  }
}
