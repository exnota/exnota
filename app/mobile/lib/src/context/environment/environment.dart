import 'dart:convert';

import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'environment.g.dart';
part 'environment.freezed.dart';

class EnvironmentContextLoader extends ConsumerWidget {
  const EnvironmentContextLoader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(_environmentInternalProvider);

    // Directionality is needed because any content rendered here will not be
    // within a MaterialApp instance and throw an error.
    return environment.when(
      loading: () {
        return const Directionality(
            textDirection: TextDirection.ltr,
            child: CircularProgressIndicator());
      },
      error: (error, _) => Directionality(
          textDirection: TextDirection.ltr, child: Text('Error: $error')),
      data: (userContext) {
        return child;
      },
    );
  }
}

@Riverpod(keepAlive: true)
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

enum Environment {
  local,
  prod,
}

@freezed
class EnvironmentSettings with _$EnvironmentSettings {
  const factory EnvironmentSettings({
    required Environment environment,
  }) = _EnvironmentSettings;

  factory EnvironmentSettings.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentSettingsFromJson(json);
}
