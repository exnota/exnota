import 'dart:convert';

import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/data/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/note/service/note_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CreateAudioNoteSyncCommand extends SyncCommand<AudioNote> {
  final String filePath;

  CreateAudioNoteSyncCommand(
      {required int id, required String entityId, required this.filePath})
      : super(id: id, entityId: entityId);

  @override
  Future<void> request(Ref ref) async {
    final logger = Logger();

    var uri = ref.read(uriServiceProvider(path: 'note/notes'));
    final notionSettings = ref.read(notionSettingsRepoProvider).valueOrNull;
    switch (notionSettings) {
      case null:
      case NotionSettingsEmpty():
      case NotionSettingsCode():
        logger.error('No access token');
        // TODO: Set error on job
        // return NoteCreateError.authError;
        // TODO: remove this
        return Future.value(null);
      case NotionSettingsAccessToken():
        // Do nothing. Don't use `default` so if a new subtype is added we're
        // forced to update this block due to the exhaustive rule.
        break;
    }

    var request = http.MultipartRequest('POST', uri)
      ..fields['type'] = 'audio'
      ..fields['accessToken'] = notionSettings.accessToken
      ..files.add(await http.MultipartFile.fromPath('file', filePath,
          contentType: MediaType('audio', 'x-m4a')));

    http.StreamedResponse streamedResponse;
    try {
      logger.info("About to send request");
      streamedResponse = await request.send();
    } catch (e) {
      logger.warn("Couldn't send request", nonPrivateData: e);
      // TODO: remove this and replace with error on command
      return Future.value(null);
      // return NoteCreateError.network;
    }

    logger.info('Received response');
    var response = await http.Response.fromStream(streamedResponse);
    // 201 is the expected response
    if ([201, 200].contains(response.statusCode)) {
      final json = jsonDecode(response.body);
      logger.info('Uploaded!');

      final transcription = json["transcription"];
      if (transcription is! String) {
        throw Exception("Invalid transcription from server");
      }
      String? url;
      if (json["url"] is String) {
        url = json["url"];
      }
      logger.debug("transcription=$transcription");
      logger.debug("url=$url");

      ref
          .read(noteServiceProvider.notifier)
          .insert(filePath: filePath, transcription: transcription, url: url);

      await ref.read(noteServiceProvider.notifier).setNoteSynced(
          id: entityId, title: transcription, integratedUrl: url ?? "");

      return;
    }

    // TODO: Handle error cases
    final json = jsonDecode(response.body);
    final code = json["code"];
    if (code is String && code == "AUTH_ERROR") {
      print("AUTH_ERROR");
      // return NoteCreateError.authError;
      return Future.value(null);
    } else if (code is String && code == "NO_PAGE_ERROR") {
      print("NO_PAGE_ERROR");
      // return NoteCreateError.noPageError;
      return Future.value(null);
    }
    print("Upload fail");
    print("Status=${response.statusCode}");
    print("reasonPhrase=${response.reasonPhrase}");
    print("code=${json["code"]}");
    // return NoteCreateError.other;
    return Future.value(null);
  }

  @override
  Map<String, dynamic> internalDataToJson() {
    return {'filePath': filePath};
  }

  factory CreateAudioNoteSyncCommand.fromJson(
      {required int id,
      required String entityId,
      required Map<String, dynamic> json,
      required SyncCommandStatus status}) {
    return CreateAudioNoteSyncCommand(
        id: id, entityId: entityId, filePath: json['filePath'] as String);
  }
}
