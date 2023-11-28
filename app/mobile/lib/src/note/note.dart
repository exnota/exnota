import 'package:exnota/src/note/capture.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

sealed class Note {
  final String id;
  final String title;
  final List<Capture> captures;

  Note({
    required this.id,
    required this.title,
    required this.captures,
  });
}

class VoiceNote extends Note {
  VoiceNote({
    required String id,
    required String title,
    required List<AudioFileCapture> captures,
  }) : super(id: id, title: title, captures: List.unmodifiable(captures));
}

// TODO: Remove
@freezed
sealed class AudioNote with _$AudioNote {
  const factory AudioNote({
    required String path,
    required String transcription,
    String? url,
  }) = _AudioNote;
}
