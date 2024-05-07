import 'dart:async';

import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/integration/integration.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_auth_service.g.dart';
part 'notion_auth_service.freezed.dart';

@freezed
class BasicResponse<T> with _$BasicResponse<T> {
  const factory BasicResponse({required T result, required String? error}) =
      _BasicResponse<T>;
}

@riverpod
class NotionAuthService extends _$NotionAuthService {
  final _log = Logger(context: 'NotionAuthService');

  @override
  FutureOr<void> build() {
    return null;
  }

  Future<BasicResponse<String>> getAuthUrl() async {
    final completor = Completer<BasicResponse<String>>();
    final request = AuthUrlRequest();
    await ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (url) {
            _log.debug('getAuthUrl: Get auth url returned $url');
            completor.complete(
              BasicResponse(result: url, error: null),
            );
          },
          onError: (error) {
            _log.error('getAuthUrl: Get auth url errored', exception: error);
            completor.complete(
              BasicResponse(result: '', error: error.toString()),
            );
          },
        );

    return completor.future;
  }

  Future<BasicResponse<Integration?>> createIntegration(
      {required String code}) async {
    final completor = Completer<BasicResponse<Integration?>>();
    final request = CreateNotionIntegrationRequest(code: code);
    await ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (integration) {
            _log.debug(
                'createIntegration: Created integration with id ${integration.id}');
            completor.complete(
              BasicResponse(result: integration, error: null),
            );
          },
          onError: (error) {
            _log.error('createIntegration: Create integration errored',
                exception: error);
            completor.complete(
              BasicResponse(result: null, error: error.toString()),
            );
          },
        );
    return completor.future;
  }

  Future<BasicResponse<bool>> updateIntegration(
      {required String integrationId, required String code}) async {
    final completor = Completer<BasicResponse<bool>>();
    final request = UpdateNotionIntegration(
      integrationId: integrationId,
      code: code,
    );
    unawaited(ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (success) {
            if (!success) {
              _log.error(
                  'updateIntegration: Update integration failed for id $integrationId');
              completor.complete(
                const BasicResponse(result: false, error: 'Failed to update'),
              );
              return;
            }
            _log.debug(
                'updateIntegration: Updated integration succeeded for id $integrationId');
            completor.complete(
              const BasicResponse(result: true, error: null),
            );
          },
          onError: (error) {
            _log.error(
                'updateIntegration: Update integration errored for id $integrationId',
                exception: error);
            completor.complete(
              BasicResponse(result: false, error: error.toString()),
            );
          },
        ));
    return completor.future;
  }
}

class AuthUrlRequest extends HandledRequest<String> {
  final Logger _log = Logger(context: 'AuthUrlRequest');

  AuthUrlRequest() : super();

  @override
  Future<String> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Requesting auth url from Notion');
    final result = await pb.send(
      '/api/exnota/integration/notion/mobile-code-request-path',
    );
    final url = (result as Map<String, dynamic>? ?? {})['url'] as String;
    return url;
  }
}

class CreateNotionIntegrationRequest extends HandledRequest<Integration> {
  final Logger _log = Logger(context: 'CreateNotionIntegrationRequest');

  late final String code;

  CreateNotionIntegrationRequest({required this.code}) : super();

  @override
  Future<Integration> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('Creating Notion integration');
    // TODO: Fix folder structure, e.g. this is integration but it's in
    // "user" folder
    final userId = ref.read(activeUserIdOrThrowSyncProvider);

    final record = await pb.collection(collectionIntegration).create(
          body: Integration.createNotionIntegrationRequestBody(
            type: IntegrationType.notion,
            code: code,
            userId: userId,
          ),
        );
    final integration = Integration.fromRecord(record);
    return integration;
  }
}

class UpdateNotionIntegration extends HandledRequest<bool> {
  final Logger _log = Logger(context: 'UpdateNotionIntegration');

  late final String integrationId;
  late final String code;

  UpdateNotionIntegration({required this.code, required this.integrationId})
      : super();

  @override
  Future<bool> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Creating Notion integration');
    // TODO: Fix folder structure, e.g. this is integration but it's in
    // "user" folder
    await pb.collection(collectionIntegration).update(
          integrationId,
          body: Integration.updateNotionIntegrationRequestBody(
            code: code,
          ),
        );
    return true;
  }
}
