import 'dart:convert';

import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/repo/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/entity_id.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/service/note_mutation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef CreateAudioNoteCapture = ({String id, String filePath});

class CreateAudioNoteSyncCommand extends NoteSyncCommand {
  final CreateAudioNoteCapture capture;

  CreateAudioNoteSyncCommand._(
      {required EntityId id,
      required String entityId,
      required this.capture,
      required SyncCommandStatus status})
      : super(id: id, entityId: entityId, status: status);

  @override
  String? get captureId => capture.id;

  @override
  Future<SyncCommandError?> request(Ref ref) async {
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
      ..files.add(await http.MultipartFile.fromPath('file', capture.filePath,
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

      await ref.read(noteMutationServiceProvider.notifier).setAudioFileData(
          captureId: capture.id,
          transcription: transcription,
          integratedUrl: url ?? "");

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

  factory CreateAudioNoteSyncCommand.createPending(
      {required String entityId,
      required CreateAudioNoteCapture capture,
      required SyncCommandStatus status}) {
    return CreateAudioNoteSyncCommand._(
        id: EntityPendingId(),
        entityId: entityId,
        capture: capture,
        status: status);
  }

  factory CreateAudioNoteSyncCommand.fromDb(
      {required int id,
      required String entityId,
      required String captureId,
      required String filePath,
      required SyncCommandStatus status}) {
    return CreateAudioNoteSyncCommand._(
        id: EntityWithId(id),
        entityId: entityId,
        capture: (id: captureId, filePath: filePath),
        status: status);
  }
}
