import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/block/workspace.dart';

class WorkspaceRepoMapper {
  static Workspace fromRepo(WorkspaceTableData repo) {
    return Workspace(
      id: repo.id,
      name: repo.name,
      type: _typeFromRepo(repo.type),
      integrationId: repo.integration,
      external: _fromExternalRepo(repo.external),
      userId: repo.user,
      created: repo.created,
      updated: repo.updated,
      archived: repo.archived,
    );
  }

  static WorkspaceTableData toRepo(Workspace workspace) {
    return WorkspaceTableData(
      id: workspace.id,
      name: workspace.name,
      type: _typeToRepo(workspace.type),
      integration: workspace.integrationId,
      external: _toExternalRepo(workspace.external),
      user: workspace.userId,
      created: workspace.created,
      updated: workspace.updated,
      archived: workspace.archived,
    );
  }

  static WorkspaceType _typeFromRepo(String type) {
    switch (type) {
      case 'database':
        return WorkspaceType.database;
      case 'custom':
        return WorkspaceType.custom;
      default:
        return WorkspaceType.unknown;
    }
  }

  static String _typeToRepo(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.database:
        return 'database';
      case WorkspaceType.custom:
        return 'custom';
      case WorkspaceType.unknown:
        return 'unknown';
    }
  }

  static WorkspaceExternal? _fromExternalRepo(String? external) {
    if (external == null) {
      return null;
    }
    final json = jsonDecode(external) as Map<String, dynamic>;
    final statusStr = json['status'];
    if (statusStr is String) {
      final WorkspaceExternalStatus status;
      switch (statusStr) {
        case 'connected':
          status = WorkspaceExternalStatus.connected;
          break;
        case 'disconnected':
          status = WorkspaceExternalStatus.disconnected;
          break;
        case 'archived':
          status = WorkspaceExternalStatus.archived;
          break;
        default:
          status = WorkspaceExternalStatus.unknown;
      }
      return WorkspaceExternal(status: status);
    } else {
      return const WorkspaceExternal(status: null);
    }
  }

  static String? _toExternalRepo(WorkspaceExternal? external) {
    if (external == null) {
      return null;
    }

    final String? status;
    switch (external.status) {
      case WorkspaceExternalStatus.connected:
        status = 'connected';
        break;
      case WorkspaceExternalStatus.disconnected:
        status = 'disconnected';
        break;
      case WorkspaceExternalStatus.archived:
        status = 'archived';
        break;
      case WorkspaceExternalStatus.unknown:
        status = null;
      case null:
        status = null;
    }

    if (status == null) {
      return null;
    }

    return jsonEncode({'status': status});
  }
}
