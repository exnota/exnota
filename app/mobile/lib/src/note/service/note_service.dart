import 'package:exnota/src/integration/data/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/note/audio_note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

part 'note_service.g.dart';

@riverpod
class NoteService extends _$NoteService {
  @override
  FutureOr<List<AudioNote>> build() {
    return [];
  }

  Future<bool> create(String path) async {
    var uri = Uri.https('exnota.com', 'api/note/notes');
    final notionSettings = ref.read(notionSettingsRepoProvider).valueOrNull;
    switch (notionSettings) {
      case null:
      case NotionSettingsEmpty():
      case NotionSettingsCode():
        print('No access token');
        return false;
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
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    // 201 is expected
    if ([201, 200].contains(response.statusCode)) {
      final transcription = response.body.trim();
      print('Uploaded!');
      print("transcription=$transcription");
      final previousState = await future;
      state = AsyncData([
        ...previousState,
        AudioNote(path: path, transcription: transcription)
      ]);
      return true;
    }
    print("Upload fail");
    print("Status=${response.statusCode}");
    print("reasonPhrase=${response.reasonPhrase}");
    return false;
  }
}
