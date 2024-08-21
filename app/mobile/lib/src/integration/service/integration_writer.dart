import 'dart:async';

import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'integration_writer.g.dart';

@riverpod
class IntegrationWriter extends _$IntegrationWriter {
  final _log = Logger(context: 'IntegrationWriter');

  @override
  FutureOr<void> build() {
    // No-op
  }

  Future<BasicResponse<void>> syncIntegrationDestinations(
      {required String integrationId}) async {
    final completor = Completer<BasicResponse<void>>();

    final request =
        SyncIntegrationDestinationsRequest(integrationId: integrationId);
    await ref.read(requestHandlerProvider.notifier).submit(
        request: request,
        onSuccess: (results) {
          _log.debug('Synced destinations for integration $integrationId');
          completor.complete(const BasicResponse.success(result: null));
        },
        onError: (error) {
          _log.error(
              'Error syncing destinations for integration $integrationId',
              exception: error);
          completor.complete(
              BasicResponse.error(error: error.toString(), errorCode: null));
        });

    return completor.future;
  }
}

class SyncIntegrationDestinationsRequest extends HandledRequest<void> {
  final Logger _log = Logger(context: 'SyncIntegrationDestinationsRequest');

  final String integrationId;

  SyncIntegrationDestinationsRequest({required this.integrationId}) : super();

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Verifying status for id $integrationId');
    await pb.send('/api/exnota/integration/sync-destinations',
        method: 'POST', body: {'integration_id': integrationId});
  }
}
