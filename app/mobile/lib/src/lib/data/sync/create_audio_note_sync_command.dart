import 'dart:convert';

import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/data/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/note/service/note_mutation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef CreateAudioNoteCapture = ({String id, String filePath});

class CreateAudioNoteSyncCommand extends SyncCommand<VoiceNote> {
  final CreateAudioNoteCapture capture;

  CreateAudioNoteSyncCommand(
      {required int id, required String entityId, required this.capture})
      : super(id: id, entityId: entityId);

  @override
  Future<SyncCommandError?> request(Ref ref) async {
    final logger = Logger();

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

      await ref.read(noteMutationServiceProvider.notifier).setAudioFileSynced(
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

  static Map<String, dynamic> dataToJson(
      {required CreateAudioNoteCapture capture}) {
    return {
      'capture': {
        'id': capture.id,
        'filePath': capture.filePath,
      }
    };
  }

  factory CreateAudioNoteSyncCommand.fromDb(
      {required int id,
      required String entityId,
      required Map<String, dynamic> data,
      required SyncCommandStatus status}) {
    final capture = data['capture'];
    final captureId = capture['id'] as String;
    final filePath = capture['filePath'] as String;
    return CreateAudioNoteSyncCommand(
        id: id,
        entityId: entityId,
        capture: (id: captureId, filePath: filePath));
  }
}
