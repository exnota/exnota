import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_file.freezed.dart';

@freezed
class LocalFile with _$LocalFile {
  const factory LocalFile({
    required String id,
    required EntityType entityType,
    required String entityId,
    required String path,
    required DateTime createdAt,
    required DateTime? syncedAt,
  }) = _LocalFile;
}

enum EntityType {
  block,
}
