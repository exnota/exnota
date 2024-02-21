import 'dart:convert';

import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_settings.g.dart';
part 'local_settings.freezed.dart';

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

/// Provides currently selected theme mode.
///
/// Can't be named ThemeMode due to collisions with the flutter material enum.
/// Even with an import alias in this file, the generated file ends up with a
/// collision and errors.
@riverpod
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  ThemeMode build() {
    return ref.watch(_localSettingsInternalProvider).requireValue.themeMode;
  }

  Future<void> setThemeMode(ThemeMode? themeMode) async {
    return await ref
        .read(_localSettingsInternalProvider.notifier)
        .setThemeMode(themeMode);
  }
}

// ----------------------------------------------------------------------------
// Context loader providers
// ----------------------------------------------------------------------------

/// Returns the parent provider's loading status and won't refresh when the
/// parents state value changes, so can be used as as part of a guard to ensure
/// the parent provider is loaded.
@riverpod
ProviderLoadingStatus localSettingsLoadingStatus(
    LocalSettingsLoadingStatusRef ref) {
  final userContext = ref.watch(_localSettingsInternalProvider);
  return userContext.maybeWhen(
    data: (_) => ProviderLoadingStatus.loaded,
    error: (_, __) => ProviderLoadingStatus.error,
    orElse: () => ProviderLoadingStatus.loading,
  );
}

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

/// Local app settings.
///
/// I.e. settings persisted only on the device, not to the server.
///
/// Important that changing this state does not cause a rebuild of the router.
/// Otherwise, changing theme mode results in the user losing their place.
@Riverpod(keepAlive: true)
class _LocalSettingsInternal extends _$LocalSettingsInternal {
  final Logger _log = Logger(context: 'LocalSettingsInternal');

  @override
  Future<LocalSettings> build() async {
    _log.info('Building');
    final storage = SecureStorage();
    final settingsJson =
        await storage.read(key: SecureStorageKey.localSettings);
    if (settingsJson != null && settingsJson.isNotEmpty) {
      _log.info('build: Found local settings in secure storage');
      return LocalSettings.fromJson(jsonDecode(settingsJson));
    } else {
      _log.info('build: No local settings found in secure storage');
      return const LocalSettings(
        themeMode: ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode? themeMode) async {
    _log.info('setThemeMode: Setting theme mode to $themeMode');
    final prev = await future;
    final next = prev.copyWith(themeMode: themeMode ?? ThemeMode.system);
    state = AsyncData(next);

    _log.info('setThemeMode: Writing local settings to secure storage');
    final storage = SecureStorage();
    await storage.write(
        key: SecureStorageKey.localSettings, value: jsonEncode(next.toJson()));
  }
}

@freezed
class LocalSettings with _$LocalSettings {
  const factory LocalSettings({
    required ThemeMode themeMode,
  }) = _LocalSettings;

  factory LocalSettings.fromJson(Map<String, Object?> json) =>
      _$LocalSettingsFromJson(json);
}
