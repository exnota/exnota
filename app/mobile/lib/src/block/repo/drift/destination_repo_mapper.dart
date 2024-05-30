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
      final DestinationExternalNotionStatus notionStatus;

      switch (notionStatusStr) {
        case 'connected':
          notionStatus = DestinationExternalNotionStatus.connected;
          break;
        case 'not-found':
          notionStatus = DestinationExternalNotionStatus.notFound;
          break;
        case 'archived':
          notionStatus = DestinationExternalNotionStatus.archived;
          break;
        case 'unknown-error':
          notionStatus = DestinationExternalNotionStatus.unknownError;
          break;
        case 'rate-limited':
          notionStatus = DestinationExternalNotionStatus.rateLimited;
          break;
        default:
          notionStatus = DestinationExternalNotionStatus.unknown;
      }
      return DestinationExternal(notionStatus: notionStatus);
    } else {
      return const DestinationExternal(
          notionStatus: DestinationExternalNotionStatus.unknown);
    }
  }

  static String? _toExternalRepo(DestinationExternal? external) {
    if (external == null) {
      return null;
    }
    final String notionStatus;
    switch (external.notionStatus) {
      case DestinationExternalNotionStatus.connected:
        notionStatus = 'connected';
        break;
      case DestinationExternalNotionStatus.notFound:
        notionStatus = 'not-found';
        break;
      case DestinationExternalNotionStatus.archived:
        notionStatus = 'archived';
        break;
      case DestinationExternalNotionStatus.unknownError:
        notionStatus = 'unknown-error';
        break;
      case DestinationExternalNotionStatus.rateLimited:
        notionStatus = 'rate-limited';
        break;
      default:
        notionStatus = 'unknown';
    }

    return jsonEncode({'notion_status': notionStatus});
  }
}
