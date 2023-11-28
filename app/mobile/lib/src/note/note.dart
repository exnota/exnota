import 'package:exnota/src/note/capture.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

enum LocalStatus { capturing, captured, synced }

sealed class LocalData {
  final LocalStatus status;

  const LocalData({
    required this.status,
  });
}

sealed class Note {
  abstract final String id;
  abstract final String title;
  abstract final List<Capture> captures;
  abstract final LocalData localData;
}

class AudioNoteLocalData extends LocalData {
  final String path;

  const AudioNoteLocalData({
    required this.path,
    required LocalStatus status,
  }) : super(status: status);
}

class VoiceNote extends Note {
  @override
  final String id;

  @override
  final String title;

  @override
  final List<AudioFileCapture> captures;

  @override
  final LocalData localData;

  VoiceNote({
    required this.id,
    required this.title,
    required List<AudioFileCapture> captures,
    required this.localData,
  }) : captures = List.unmodifiable(captures);
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
