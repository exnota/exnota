import 'package:exnota/src/block/repo/drift/destination_repo.dart';
import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'destination_importer.g.dart';

@riverpod
class DestinationImporter extends _$DestinationImporter {
  final _log = Logger(context: 'DestinationImporter');

  @override
  FutureOr<void> build() {
    // No-op
  }

  Future<BasicResponse<void>> importForWorkspace(
      {required String workspaceId}) async {
    // Request destinations
    final request = ListDestinationsForWorkspaceRequest(
      workspaceId: workspaceId,
    );
    final requestResult =
        await ref.read(requestHandlerProvider.notifier).submitWrapped(
              request: request,
            );

    // Import to database
    switch (requestResult) {
      case BasicResponseSuccess(:final result):
        await _importAll(result);
        return const BasicResponse.success(result: null);
      case BasicResponseError():
        return requestResult;
    }
  }

  // Does not catch errors
  Future<void> _import(RecordModel? record) async {
    if (record == null) {
      _log.warn('No destination record to import');
      return;
    }

    final repo = ref.read(destinationRepoProvider);
    try {
      final destination = Destination.fromRecord(record);

      _log.debug('Upserting destination ${destination.id}');
      await repo.upsert(destination);
    } catch (e) {
      _log.error('Error importing destination ${record.id}', exception: e);
      rethrow;
    }
  }

  Future<void> _importAll(List<RecordModel> records) async {
    _log.debug('Importing ${records.length} destination records');

    // Don't use a transaction. We don't want one failed import to block the
    // rest.
    for (final record in records) {
      await _import(record);
    }
  }
}

class ListDestinationsForWorkspaceRequest
    extends HandledRequest<List<RecordModel>> {
  final Logger _log = Logger(context: 'ListDestinationsForWorkspaceRequest');

  final String workspaceId;

  ListDestinationsForWorkspaceRequest({required this.workspaceId});

  @override
  Future<List<RecordModel>> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('request: listing destinations for workspace $workspaceId');

    return await pb
        .collection(collectionDestination)
        .getFullList(filter: '$destinationFieldWorkspace = "$workspaceId"');
  }
}
