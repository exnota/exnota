import 'dart:async';

import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/integration/notion_destination.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'destination_exporter.g.dart';

@riverpod
class DestinationExporter extends _$DestinationExporter {
  final _log = Logger(context: 'DestinationExporter');

  @override
  void build() {
    // no-op
  }

  /// Archives all non-archived destinations and creates a new destination.
  Future<BasicResponse<void>> replaceDestination(
      {required String workspaceId, required NotionObject notionObject}) async {
    final destinations = await ref.read(destinationListerProvider.future);

    // Archive all non-archived destinations
    for (final destination in destinations) {
      if (destination.archived != null) {
        _log.debug(
            '[replaceDestination] Destination ${destination.id} is already archived');
        continue;
      }

      _log.debug(
          '[replaceDestination] Archiving destination ${destination.id}');
      final response = await ref
          .read(requestHandlerProvider.notifier)
          .submitWithBasicResponse(
              request: ArchiveDestinationRequest(destination: destination));
      switch (response) {
        case BasicResponseSuccess(:final result):
          _log.debug(
              '[replaceDestination] Archived destination ${destination.id}');
          await ref.read(destinationImporterProvider.notifier).importRecord(
                record: result,
              );
          continue;
        case BasicResponseError():
          return response;
      }
    }

    // Create new destination
    _log.debug('[replaceDestination] Creating new destination');
    return await _createNotionDestination(
      workspaceId: workspaceId,
      notionObject: notionObject,
    );
  }

  Future<BasicResponse<void>> _createNotionDestination(
      {required String workspaceId, required NotionObject notionObject}) async {
    _log.debug(
        '[createNotionDestination] Creating Notion destination for object ${notionObject.id} in workspace $workspaceId');
    // Save to backend
    final request = CreateDestinationRequest(
        workspaceId: workspaceId,
        userId: ref.read(activeUserIdOrThrowSyncProvider),
        notionObject: notionObject);
    final response = await ref
        .read(requestHandlerProvider.notifier)
        .submitWithBasicResponse(request: request);

    // Import to local database
    switch (response) {
      case BasicResponseSuccess(:final result):
        _log.debug(
            '[createNotionDestination] Created destination ${result.id} for object ${notionObject.id} in workspace $workspaceId');
        await ref
            .read(
              destinationImporterProvider.notifier,
            )
            .importRecord(
              record: result,
            );
        return response;
      case BasicResponseError():
        _log.error(
            '[createNotionDestination] Failed to create destination for object ${notionObject.id} in workspace $workspaceId');
        return response;
    }
  }
}

class CreateDestinationRequest extends HandledRequest<RecordModel> {
  final Logger _log = Logger(context: 'WorkspaceExportDestinationsRequest');

  late final String workspaceId;
  late final String userId;
  late final NotionObject notionObject;

  CreateDestinationRequest(
      {required this.workspaceId,
      required this.userId,
      required this.notionObject});

  @override
  Future<RecordModel> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Exporting destinations for workspace');

    return await pb.collection(collectionDestination).create(
          body: Destination.createRequestBodyForNotion(
            workspaceId: workspaceId,
            userId: userId,
            notionObject: notionObject,
          ),
        );
  }
}

class ArchiveDestinationRequest extends HandledRequest<RecordModel> {
  final Logger _log = Logger(context: 'ArchiveDestinationRequest');

  late final Destination destination;

  ArchiveDestinationRequest({required this.destination});

  @override
  Future<RecordModel> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Archiving destination');

    return await pb.collection(collectionDestination).update(
          destination.id,
          body: Destination.createArchiveRequestBody(),
        );
  }
}
