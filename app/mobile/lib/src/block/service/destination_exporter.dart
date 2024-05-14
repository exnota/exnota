import 'dart:async';

import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/integration/notion_destination.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
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

  Future<BasicResponse<void>> createNotionDestination(
      {required String workspaceId, required NotionObject notionObject}) async {
    _log.debug('Creating Notion destination for workspace $workspaceId');
    final request = WorkspaceExportDestinationsRequest(
        workspaceId: workspaceId,
        userId: ref.read(activeUserIdOrThrowSyncProvider),
        notionObject: notionObject);
    return await ref
        .read(requestHandlerProvider.notifier)
        .submitWithBasicResponse(request: request);
  }
}

class WorkspaceExportDestinationsRequest extends HandledRequest<void> {
  final Logger _log = Logger(context: 'WorkspaceExportDestinationsRequest');

  late final String workspaceId;
  late final String userId;
  late final NotionObject notionObject;

  WorkspaceExportDestinationsRequest(
      {required this.workspaceId,
      required this.userId,
      required this.notionObject});

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Exporting destinations for workspace');

    await pb.collection(collectionDestination).create(
      body: {
        'id': generateId(),
        // Name will be overridden by the server from Notion
        'name': 'New destination',
        'workspace': workspaceId,
        'user': userId,
        'external': {
          'config': notionObject.toJson(),
        },
      },
    );
  }
}
