import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_note.freezed.dart';

@freezed
sealed class AudioNote with _$AudioNote {
  const factory AudioNote({
    required String path,
    required String transcription,
    String? url,
  }) = _AudioNote;
}
