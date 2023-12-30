import 'dart:convert';

import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/repo/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/entity_id.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/get_local_file_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/service/block_mutation_service.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ExecuteTransactionSyncCommand extends SyncCommand<Transaction> {
  final Transaction transaction;

  ExecuteTransactionSyncCommand._(
      {required EntityId id,
      required String entityId,
      required this.transaction,
      required SyncCommandStatus status})
      : super(id: id, entityId: entityId, status: status);

  @override
  Future<SyncCommandError?> request(Ref ref) async {
    final file = await ref
        .read(getLocalFileForEntityProvider(entityId, EntityType.block).future);
    if (file == null) {
      return Future.value(SyncCommandError("File not found: $entityId"));
    }

    final logger = Logger(context: '$runtimeType.request');

    var uri = ref.read(uriServiceProvider(path: 'note/notes'));
    final notionSettings = ref.read(notionSettingsRepoProvider).valueOrNull;
    switch (notionSettings) {
      case null:
      case NotionSettingsEmpty():
      case NotionSettingsCode():
        logger.error('No access token');
        return Future.value(const SyncCommandError('No access token'));
      case NotionSettingsAccessToken():
        // Do nothing. Don't use `default` so if a new subtype is added we're
        // forced to update this block due to the exhaustive rule.
        break;
    }

    var request = http.MultipartRequest('POST', uri)
      ..fields['type'] = 'audio'
      ..fields['accessToken'] = notionSettings.accessToken
      ..files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: MediaType('audio', 'x-m4a')));

    http.StreamedResponse streamedResponse;
    try {
      logger.info("About to send request");
      streamedResponse = await request.send();
    } catch (e) {
      logger.warn("Couldn't send request", nonPrivateData: e);
      return Future.value(const SyncCommandError("Couldn't send request"));
    }

    logger.info('Received response');
    var response = await http.Response.fromStream(streamedResponse);
    // 201 is the expected response
    if ([201, 200].contains(response.statusCode)) {
      final json = jsonDecode(response.body);
      logger.info('Uploaded!');

      final transcription = json["transcription"];
      if (transcription is! String) {
        logger.error("Invalid transcription from server");
        return Future.value(const SyncCommandError("Invalid transcription"));
      }
      String? url;
      if (json["url"] is String) {
        url = json["url"];
      }

      await ref.read(blockMutationServiceProvider.notifier).setAudioBlockData(
          blockId: entityId,
          transcription: [transcription],
          externalUrl: url ?? '');

      return null;
    }

    final json = jsonDecode(response.body);
    final code = json["code"];
    if (code is String && code == "AUTH_ERROR") {
      logger.warn("AUTH_ERROR");
      return Future.value(const SyncCommandError("AUTH_ERROR"));
    } else if (code is String && code == "NO_PAGE_ERROR") {
      logger.warn("NO_PAGE_ERROR");
      return Future.value(const SyncCommandError("NO_PAGE_ERROR"));
    }
    logger.error("Unknown error syncing", nonPrivateData: {
      "status": response.statusCode,
      "code": code,
      "reasonPhrase": response.reasonPhrase,
    });
    return Future.value(SyncCommandError(
        "Unknown error syncing. Code: $code, status: ${response.statusCode}, reasonPhrase: ${response.reasonPhrase}"));
  }

  // Factories

  factory ExecuteTransactionSyncCommand.createPending(
      {required String entityId, required Transaction transaction}) {
    return ExecuteTransactionSyncCommand._(
        id: EntityPendingId(),
        entityId: entityId,
        transaction: transaction,
        status: SyncCommandStatus.waiting);
  }

  factory ExecuteTransactionSyncCommand.fromDb(
      {required int id,
      required String entityId,
      required Transaction transaction,
      required SyncCommandStatus status}) {
    return ExecuteTransactionSyncCommand._(
        id: EntityWithId(id),
        entityId: entityId,
        transaction: transaction,
        status: status);
  }
}
