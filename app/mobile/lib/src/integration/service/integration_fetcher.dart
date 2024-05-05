import 'dart:async';

import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/integration/integration.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'integration_fetcher.freezed.dart';
part 'integration_fetcher.g.dart';

@freezed
class IntegrationResponse with _$IntegrationResponse {
  const factory IntegrationResponse({
    required Integration? integration,
    required String? error,
  }) = _IntegrationResponse;
}

@freezed
class VerifyResponse with _$VerifyResponse {
  const factory VerifyResponse(
      {required bool success, required String? error}) = _VerifyResponse;
}

@riverpod
class IntegrationFetcher extends _$IntegrationFetcher {
  final _log = Logger(context: 'IntegrationFetcher');

  @override
  FutureOr<void> build() {
    // No-op
  }

  Future<IntegrationResponse> fetch({required IntegrationType type}) async {
    final completor = Completer<IntegrationResponse>();

    final request = FetchIntegrationRequest(type: type);
    await ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (results) {
            _log.debug('Fetched integrations for type ${type.fieldName}');

            if (results.isEmpty) {
              _log.debug('No integrations found for type ${type.fieldName}');
              completor.complete(
                const IntegrationResponse(integration: null, error: null),
              );
              return;
            }

            if (results.length > 1) {
              _log.error(
                  'Multiple integrations found for type ${type.fieldName}');
              completor.complete(
                const IntegrationResponse(
                    integration: null, error: 'Multiple integrations found'),
              );
              return;
            }

            final integration = Integration.fromRecord(results.first);
            completor.complete(
              IntegrationResponse(integration: integration, error: null),
            );
          },
          onError: (error) {
            _log.error('Error fetching integrations for type ${type.fieldName}',
                exception: error);
            completor.complete(
              IntegrationResponse(integration: null, error: error.toString()),
            );
          },
        );

    return completor.future;
  }

  Future<VerifyResponse> verify(String integrationId) async {
    final completor = Completer<VerifyResponse>();
    final request = VerifyIntegrationRequest(integrationId: integrationId);
    await ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (success) {
            _log.debug('verify: Integration verification returned $success');
            completor.complete(
              VerifyResponse(success: success, error: null),
            );
          },
          onError: (error) {
            _log.error('verify: Error verifying integration', exception: error);
            completor.complete(
              VerifyResponse(success: false, error: error.toString()),
            );
          },
        );

    return completor.future;
  }
}

class FetchIntegrationRequest extends HandledRequest<List<RecordModel>> {
  final Logger _log = Logger(context: 'FetchIntegrationRequest');

  final IntegrationType type;

  FetchIntegrationRequest({required this.type}) : super();

  @override
  Future<List<RecordModel>> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('Fetching integration for type ${type.fieldName}');
    return await pb.collection(collectionIntegration).getFullList(
          filter: '$integrationFieldType = "${type.fieldName}"',
        );
  }
}

class VerifyIntegrationRequest extends HandledRequest<bool> {
  final Logger _log = Logger(context: 'VerifyIntegrationRequest');

  final String integrationId;

  VerifyIntegrationRequest({required this.integrationId}) : super();

  @override
  Future<bool> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Verifying status for id $integrationId');
    final result = await pb.send('/api/exnota/integration/verify-access',
        method: 'POST', body: {'integration_id': integrationId});
    final resultStr =
        (result as Map<String, dynamic>? ?? {})['result'] as String;
    return resultStr == 'success';
  }
}
