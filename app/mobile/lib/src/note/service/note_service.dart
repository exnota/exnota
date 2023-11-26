import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/data/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/note/audio_note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

part 'note_service.g.dart';

enum NoteCreateError { authError, noPageError, network, other }

@riverpod
class NoteService extends _$NoteService {
  @override
  FutureOr<List<AudioNote>> build() {
    return [];
  }

  Future<NoteCreateError?> create(String path) async {
    // Lint error below looks like a false positive, as uriServiceProvider
    // is not a manual provider. Copied the "family" provider implementation
    // as per: https://codewithandrea.com/articles/flutter-riverpod-generator/
    // ignore: avoid_manual_providers_as_generated_provider_dependency
    var uri = ref.read(uriServiceProvider(path: 'note/notes'));
    final notionSettings = ref.read(notionSettingsRepoProvider).valueOrNull;
    switch (notionSettings) {
      case null:
      case NotionSettingsEmpty():
      case NotionSettingsCode():
        print('No access token');
        return NoteCreateError.authError;
      case NotionSettingsAccessToken():
        // Do nothing. Don't use `default` so if a new subtype is added we're
        // forced to update this block.
        break;
    }

    var request = http.MultipartRequest('POST', uri)
      ..fields['type'] = 'audio'
      ..fields['accessToken'] = notionSettings.accessToken
      ..files.add(await http.MultipartFile.fromPath('file', path,
          contentType: MediaType('audio', 'x-m4a')));

    http.StreamedResponse streamedResponse;
    try {
      print("About to send request");
      streamedResponse = await request.send();
    } catch (e) {
      print("Couldn't send request=$e");
      return NoteCreateError.network;
    }
    print('Received response');
    var response = await http.Response.fromStream(streamedResponse);
    // 201 is expected
    if ([201, 200].contains(response.statusCode)) {
      final json = jsonDecode(response.body);
      print('Uploaded!');

      final transcription = json["transcription"];
      if (transcription is! String) {
        throw Exception("Invalid transcription from server");
      }
      String? url;
      if (json["url"] is String) {
        url = json["url"];
      }
      print("transcription=$transcription");
      print("url=$url");

      final previousState = await future;
      state = AsyncData([
        ...previousState,
        AudioNote(path: path, transcription: transcription, url: url)
      ]);
      return null;
    }
    final json = jsonDecode(response.body);
    final code = json["code"];
    if (code is String && code == "AUTH_ERROR") {
      print("AUTH_ERROR");
      return NoteCreateError.authError;
    } else if (code is String && code == "NO_PAGE_ERROR") {
      print("NO_PAGE_ERROR");
      return NoteCreateError.noPageError;
    }
    print("Upload fail");
    print("Status=${response.statusCode}");
    print("reasonPhrase=${response.reasonPhrase}");
    print("code=${json["code"]}");
    return NoteCreateError.other;
  }
}
