import 'dart:convert';

import 'package:exnota/src/note/note.dart';
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
    var uri = Uri.https('exnota.com', 'api/notes');
    var request = http.MultipartRequest('POST', uri)
      // ..fields['user'] = 'someemail@google.com'
      ..files.add(await http.MultipartFile.fromPath('file', path,
          contentType: MediaType('audio', 'x-m4a')));
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    // 201 is expected
    if ([201, 200].contains(response.statusCode)) {
      print('Uploaded!');
      print("transcription=${response.body}");
      return true;
    }
    print("Upload fail");
    print("Status=${response.statusCode}");
    print("reasonPhrase=${response.reasonPhrase}");
    return false;
  }
}
