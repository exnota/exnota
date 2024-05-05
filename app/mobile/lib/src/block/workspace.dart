// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

const collectionWorkspace = 'workspace';

@freezed
class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    String? name,
    required WorkspaceType type,
    required String? integrationId,
    WorkspaceExternal? external,
    required String userId,
    DateTime? created,
    DateTime? updated,
    DateTime? archived,
  }) = _Workspace;

  const Workspace._();

  factory Workspace.fromRecord(RecordModel model) {
    final WorkspaceType type;
    switch (model.data['type']) {
      case 'database':
        type = WorkspaceType.database;
        break;
      case 'custom':
        type = WorkspaceType.custom;
        break;
      default:
        type = WorkspaceType.unknown;
    }

    WorkspaceExternal? external;
    final externalMap = model.data['external'];
    if (externalMap != null && externalMap is Map<String, dynamic>) {
      external = WorkspaceExternal.fromJson(externalMap);
    }

    return Workspace(
      id: model.id,
      name: model.data['name'],
      type: type,
      integrationId: model.data['integration'],
      external: external,
      userId: model.data['user'],
      created: DateTime.tryParse(model.created),
      updated: DateTime.tryParse(model.updated),
      // TODO: archived not currently in model
      archived: DateTime.tryParse(model.data['archived'] ?? ''),
    );
  }

  static Map<String, dynamic> createRequestBodyWithoutId({
    required WorkspaceType type,
    required String userId,
  }) {
    Map<String, dynamic> body = {};
    switch (type) {
      case WorkspaceType.database:
        body['type'] = 'database';
        break;
      case WorkspaceType.custom:
        body['type'] = 'custom';
        break;
      case WorkspaceType.unknown:
        throw Exception('Unknown workspace type');
    }

    body['user'] = userId;

    return body;
  }
}

enum WorkspaceType { database, custom, unknown }

enum WorkspaceExternalStatus {
  connected,
  disconnected,
  archived,
  unknown,
}

@freezed
class WorkspaceExternal with _$WorkspaceExternal {
  const factory WorkspaceExternal({WorkspaceExternalStatus? status}) =
      _WorkspaceExternal;

  const WorkspaceExternal._();

  factory WorkspaceExternal.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceExternalFromJson(json);
}
