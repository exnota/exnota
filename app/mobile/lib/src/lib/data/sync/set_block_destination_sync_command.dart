import 'dart:async';

import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_runner.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/block/block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'set_block_destination_sync_command.freezed.dart';
part 'set_block_destination_sync_command.g.dart';

@freezed
class SetBlockDestinationData with _$SetBlockDestinationData {
  const factory SetBlockDestinationData({
    required String blockId,
    required String destinationId,
  }) = _SetBlockDestinationData;

  factory SetBlockDestinationData.fromJson(Map<String, dynamic> json) =>
      _$SetBlockDestinationDataFromJson(json);
}

class SetBlockDestinationSyncCommand extends SyncCommand<Block> {
  static final _log = Logger(context: 'SetBlockDestinationSyncCommand');

  final SetBlockDestinationData data;

  SetBlockDestinationSyncCommand._(
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
    if (current == null) {
      throw Exception('Missing current value');
    }
    final updated = current.copyWithDestination(data.destinationId);
    _log.debug('localUpdate: End');
    return Future.value(updated);
  }

  @override
  Future<Block> syncUpdate({required ProviderContainer container}) async {
    _log.debug('syncUpdate: Start');

    final request = SetBlockDestinationRequest(
        blockId: data.blockId, destinationId: data.destinationId);

    final result = await container
        .read(requestHandlerProvider.notifier)
        .submitWithBasicResponse(
          request: request,
        );

    switch (result) {
      case BasicResponseSuccess(:final result):
        _log.debug('syncUpdate: Success');
        return Block.fromRecord(result);
      case BasicResponseError(error: final error):
        _log.error('syncUpdate: Error', exception: error);
        throw Exception(error);
    }
  }

  // Factories
  factory SetBlockDestinationSyncCommand.createWaiting(
      {required String userId, required SetBlockDestinationData data}) {
    final now = Clock().now();
    return SetBlockDestinationSyncCommand._(
      id: generateId(),
      entityId: data.blockId,
      rootEntityId: data.blockId,
      userId: userId,
      status: SyncCommandStatus.waiting,
      result: null,
      createdAt: now,
      startedAt: null,
      updatedAt: now,
      data: data,
    );
  }

  factory SetBlockDestinationSyncCommand.fromDb(
      {required String id,
      required String entityId,
      required String rootEntityId,
      required String userId,
      required SetBlockDestinationData data,
      required SyncCommandStatus status,
      required String? result,
      required DateTime createdAt,
      required DateTime? startedAt,
      required DateTime updatedAt}) {
    return SetBlockDestinationSyncCommand._(
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

class SetBlockDestinationRequest extends HandledRequest<RecordModel> {
  static final Logger _log = Logger(context: 'SetBlockDestinationRequest');

  final String blockId;
  final String destinationId;

  SetBlockDestinationRequest(
      {required this.blockId, required this.destinationId});

  @override
  Duration get timeout => commandRequestTimeout;

  @override
  Future<RecordModel> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('Request: Start');
    _log.debug(
        'Request: Updating block $blockId with destination $destinationId');
    final recordModel = await pb.collection(collectionBlock).update(
          blockId,
          body: Block.generateUpdateBody(destinationId: destinationId),
        );
    _log.debug('Request: End');
    return recordModel;
  }
}
