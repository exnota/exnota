import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_file.freezed.dart';

@freezed
class LocalFile with _$LocalFile {
  const factory LocalFile({
    required String id,
    required FileType fileType,
    required Status status,
    required String path,
    required EntityType entityType,
    String? entityId,
    required DateTime created,
  }) = _LocalFile;
}

enum FileType { audioRecording }

enum EntityType {
  block,
}

enum Status { recording, saved }
