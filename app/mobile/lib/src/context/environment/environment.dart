import 'dart:convert';

import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'environment.g.dart';
part 'environment.freezed.dart';

enum Environment {
  local,
  prod,
}

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@riverpod
class EnvironmentService extends _$EnvironmentService {
  @override
  Environment build() {
    return ref.watch(_environmentInternalProvider).requireValue;
  }

  Future<void> setEnvironment(Environment? environment) async {
    return await ref
        .read(_environmentInternalProvider.notifier)
        .setEnvironment(environment);
  }
}

// ----------------------------------------------------------------------------
// Context loader providers
// ----------------------------------------------------------------------------

/// Returns the parent provider's loading status and won't refresh when the
/// parents state value changes, so can be used as as part of a guard to ensure
/// the parent provider is loaded.
@riverpod
ProviderLoadingStatus environmentLoadingStatus(
    EnvironmentLoadingStatusRef ref) {
  final userContext = ref.watch(_environmentInternalProvider);
  return userContext.maybeWhen(
    data: (_) => ProviderLoadingStatus.loaded,
    error: (_, __) => ProviderLoadingStatus.error,
    orElse: () => ProviderLoadingStatus.loading,
  );
}

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class _EnvironmentInternal extends _$EnvironmentInternal {
  final Logger _log = Logger(context: 'EnvironmentContext');

  @override
  Future<Environment> build() async {
    _log.info('build: Building environment context');
    final storage = SecureStorage();
    final settingsJson =
        await storage.read(key: SecureStorageKey.environmentSettings);
    if (settingsJson != null) {
      _log.info('build: Found settings in secure storage');
      return EnvironmentSettings.fromJson(jsonDecode(settingsJson)).environment;
    } else {
      _log.info('build: No settings found in secure storage');
      return Environment.prod;
    }
  }

  Future<void> setEnvironment(Environment? environment) async {
    _log.info('setEnvironment: Setting environment to $environment');
    final storage = SecureStorage();

    if (environment == null) {
      state = const AsyncData(Environment.prod);
      await storage.write(key: SecureStorageKey.environmentSettings, value: '');
      return;
    }

    state = AsyncData(environment);
    await storage.write(
        key: SecureStorageKey.environmentSettings,
        value:
            jsonEncode(EnvironmentSettings(environment: environment).toJson()));
  }
}

@freezed
class EnvironmentSettings with _$EnvironmentSettings {
  const factory EnvironmentSettings({
    required Environment environment,
  }) = _EnvironmentSettings;

  factory EnvironmentSettings.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentSettingsFromJson(json);
}
