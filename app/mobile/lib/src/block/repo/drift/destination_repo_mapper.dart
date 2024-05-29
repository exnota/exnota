import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/block/destination.dart';

class DestinationRepoMapper {
  static Destination fromRepo(DestinationTableData destination) {
    return Destination(
      id: destination.id,
      name: destination.name,
      workspaceId: destination.workspace,
      external: _fromExternalRepo(destination.external),
      userId: destination.user,
      created: destination.created,
      updated: destination.updated,
      archived: destination.archived,
    );
  }

  static DestinationTableData toRepo(Destination destination) {
    return DestinationTableData(
      id: destination.id,
      name: destination.name,
      workspace: destination.workspaceId,
      external: _toExternalRepo(destination.external),
      user: destination.userId,
      created: destination.created,
      updated: destination.updated,
      archived: destination.archived,
    );
  }

  static DestinationExternal? _fromExternalRepo(String? external) {
    if (external == null) {
      return null;
    }
    final json = jsonDecode(external) as Map<String, dynamic>;
    final notionStatusStr = json['notion_status'];
    if (notionStatusStr is String) {
      final DestinationExternalNotionStatus status;

      switch (notionStatusStr) {
        case 'connected':
          status = DestinationExternalNotionStatus.connected;
          break;
        case 'not-found':
          status = DestinationExternalNotionStatus.notFound;
          break;
        case 'archived':
          status = DestinationExternalNotionStatus.archived;
          break;
        case 'unknown-error':
          status = DestinationExternalNotionStatus.unknownError;
          break;
        case 'rate-limited':
          status = DestinationExternalNotionStatus.rateLimited;
          break;
        default:
          status = DestinationExternalNotionStatus.unknown;
      }
      return DestinationExternal(status: status);
    } else {
      return const DestinationExternal(
          status: DestinationExternalNotionStatus.unknown);
    }
  }

  static String? _toExternalRepo(DestinationExternal? external) {
    if (external == null) {
      return null;
    }
    final String status;
    switch (external.status) {
      case DestinationExternalNotionStatus.connected:
        status = 'connected';
        break;
      case DestinationExternalNotionStatus.notFound:
        status = 'not-found';
        break;
      case DestinationExternalNotionStatus.archived:
        status = 'archived';
        break;
      case DestinationExternalNotionStatus.unknownError:
        status = 'unknown-error';
        break;
      case DestinationExternalNotionStatus.rateLimited:
        status = 'rate-limited';
        break;
      default:
        status = 'unknown';
    }

    return jsonEncode({'notion_status': status});
  }
}
