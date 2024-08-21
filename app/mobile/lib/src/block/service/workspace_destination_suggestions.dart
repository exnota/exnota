// ignore_for_file: invalid_annotation_target

import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/common/integration/notion_destination.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_destination_suggestions.g.dart';
part 'workspace_destination_suggestions.freezed.dart';

@riverpod
class WorkspaceDestinationSuggestions
    extends _$WorkspaceDestinationSuggestions {
  final _log = Logger(context: 'WorkspaceDestinationSuggestions');

  @override
  Future<void> build() async {
    // no-op
  }

  Future<BasicResponse<GetSuggestedDestinationsResponse>> get() async {
    final workspace = await ref.read(activeWorkspaceProvider.future);
    if (workspace == null) {
      _log.error('No active workspace');
      return const BasicResponse.error(
          error: 'No active workspace', errorCode: null);
    }

    final request = WorkspaceSuggestedDestinationsRequest(
      workspaceId: workspace.id,
    );
    _log.debug('Fetching suggested destinations for workspace ${workspace.id}');
    return await ref
        .read(requestHandlerProvider.notifier)
        .submitWithBasicResponse(request: request);
  }
}

@freezed
class GetSuggestedDestinationsResponse with _$GetSuggestedDestinationsResponse {
  const factory GetSuggestedDestinationsResponse({
    @JsonKey(name: 'destinations') required Destinations destinations,
  }) = _GetSuggestedDestinationsResponse;

  const GetSuggestedDestinationsResponse._();

  factory GetSuggestedDestinationsResponse.fromJson(
          Map<String, dynamic> json) =>
      _$GetSuggestedDestinationsResponseFromJson(json);
}

class WorkspaceSuggestedDestinationsRequest
    extends HandledRequest<GetSuggestedDestinationsResponse> {
  final Logger _log = Logger(context: 'WorkspaceSuggestedDestinationsRequest');

  final String workspaceId;

  WorkspaceSuggestedDestinationsRequest({required this.workspaceId}) : super();

  @override
  Future<GetSuggestedDestinationsResponse> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('Verifying status for id $workspaceId');
    final result = await pb.send(
        '/api/exnota/workspace/get-suggested-destinations',
        method: 'GET',
        body: {'workspace_id': workspaceId});
    return GetSuggestedDestinationsResponse.fromJson(result);
  }
}
