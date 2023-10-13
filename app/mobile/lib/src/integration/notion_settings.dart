import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'notion_settings.freezed.dart';

@freezed
class NotionSettings with _$NotionSettings {
  const factory NotionSettings({
    required String code,
  }) = _NotionSettings;
}
