import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

@freezed
sealed class AudioNote with _$AudioNote {
  const factory AudioNote({
    required String path,
  }) = _AudioNote;
}
