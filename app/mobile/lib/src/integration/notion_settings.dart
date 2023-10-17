import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'notion_settings.freezed.dart';

enum Status { noAuth, codeGranted, accessTokenGranted }

@freezed
sealed class NotionSettings with _$NotionSettings {
  // Added constructor. Must not have any parameter
  const NotionSettings._();

  const factory NotionSettings.empty() = NotionSettingsEmpty;

  const factory NotionSettings.code({
    required String code,
  }) = NotionSettingsCode;

  const factory NotionSettings.accessToken({
    required String accessToken,
  }) = NotionSettingsAccessToken;
}
