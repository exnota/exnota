import 'package:exnota/src/note/capture.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

enum LocalStatus { capturing, captured, synced }

sealed class LocalData {
  abstract final LocalStatus status;
}

sealed class Note {
  abstract final String id;
  abstract final String? title;
  abstract final List<Capture> captures;
  abstract final LocalData localData;
}

class VoiceNoteLocalData implements LocalData {
  @override
  final LocalStatus status;

  final String filePath;

  VoiceNoteLocalData({
    required this.filePath,
    required this.status,
  });
}

class VoiceNote extends Note {
  @override
  final String id;

  @override
  final String? title;

  @override
  final List<AudioFileCapture> captures;

  @override
  final LocalData localData;

  VoiceNote({
    required this.id,
    this.title,
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
