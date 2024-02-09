import 'dart:convert';

import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_service.g.dart';
part 'settings_service.freezed.dart';

// TODO: This can probably replace lib/src/account/settings/environment_service.dart

@Riverpod(keepAlive: true)
class SettingsService extends _$SettingsService {
  final Logger _log = Logger(context: 'SettingsService');

  @override
  Future<Settings> build() async {
    _log.info('build: Building settings service');
    final storage = SecureStorage();
    final settingsJson = await storage.read(key: SecureStorageKey.settings);
    if (settingsJson != null) {
      _log.info('build: Found settings in secure storage');
      return Settings.fromJson(jsonDecode(settingsJson));
    } else {
      _log.info('build: No settings found in secure storage');
      return const Settings(
        themeMode: ThemeMode.system,
        environment: Environment.prod,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode? themeMode) async {
    _log.info('setThemeMode: Setting theme mode to $themeMode');
    final prev = await future;
    final next = prev.copyWith(themeMode: themeMode ?? ThemeMode.system);
    state = AsyncData(next);

    _log.info('setThemeMode: Writing settings to secure storage');
    final storage = SecureStorage();
    await storage.write(
        key: SecureStorageKey.settings, value: jsonEncode(next.toJson()));
  }

  Future<void> setEnvironment(Environment? environment) async {
    _log.info('setEnvironment: Setting environment to $environment');
    final prev = await future;
    final next = prev.copyWith(environment: environment ?? Environment.prod);
    state = AsyncData(next);

    _log.info('setEnvironment: Writing settings to secure storage');
    final storage = SecureStorage();
    await storage.write(
        key: SecureStorageKey.settings, value: jsonEncode(next.toJson()));
  }
}

// newSettings() async
// -> reads initial data from secure storage and uses it to populate state
// settings.set()
// -> sets local state AND updates ss in parallel

@freezed
class Settings with _$Settings {
  const factory Settings({
    required ThemeMode themeMode,
    required Environment environment,
  }) = _Settings;

  factory Settings.fromJson(Map<String, Object?> json) =>
      _$SettingsFromJson(json);
}

enum Environment {
  local,
  prod,
}
